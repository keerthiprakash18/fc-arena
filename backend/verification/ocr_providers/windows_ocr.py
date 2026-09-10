import asyncio
import logging
import os
import re

logger = logging.getLogger(__name__)

try:
    import winrt.windows.graphics.imaging as imaging
    import winrt.windows.media.ocr as ocr
    import winrt.windows.storage.streams as streams
    WINRT_OCR_AVAILABLE = True
except ImportError:
    WINRT_OCR_AVAILABLE = False

SCORE_PATTERN = re.compile(
    r'^\s*(\d{1,3})\s*(?:[:.\-|/]|v(?:s)?\s?)\s*(\d{1,3})\s*$',
    re.IGNORECASE,
)
PURE_INT = re.compile(r'^\d{1,3}$')


def _fallback_fields(message):
    return [
        {'field': 'home_score', 'value': None, 'confidence': 0.0, 'source_region': 'home_side'},
        {'field': 'away_score', 'value': None, 'confidence': 0.0, 'source_region': 'away_side'},
        {'field': 'match_notes', 'value': message, 'confidence': 0.0, 'source_region': 'full_image'},
    ]


def _parse_pair(text):
    m = SCORE_PATTERN.match(text)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None


def _cluster_rows(words):
    """Cluster word boxes into horizontal rows by vertical overlap."""
    words = sorted(words, key=lambda w: (w['y'], w['x']))
    rows = []
    for w in words:
        placed = False
        for row in rows:
            top, bottom = row['top'], row['bottom']
            overlap = min(bottom, w['y'] + w['h']) - max(top, w['y'])
            if overlap > 0.35 * min(bottom - top, w['h']):
                row['words'].append(w)
                row['top'] = min(top, w['y'])
                row['bottom'] = max(bottom, w['y'] + w['h'])
                placed = True
                break
        if not placed:
            rows.append({
                'top': w['y'],
                'bottom': w['y'] + w['h'],
                'words': [w],
            })
    return rows


class WindowsOCRProvider:
    def get_provider_name(self):
        return 'windows_local'

    def extract(self, image_source):
        if not WINRT_OCR_AVAILABLE:
            logger.warning('WinRT OCR packages not installed — returning zero-confidence fallback')
            return _fallback_fields('Windows OCR engine not available')

        if isinstance(image_source, (str, os.PathLike)):
            image_source = os.fspath(image_source)
            if not os.path.exists(image_source):
                logger.error('Evidence file not found: %s', image_source)
                return _fallback_fields(f'Evidence file not found: {image_source}')
            with open(image_source, 'rb') as f:
                image_bytes = f.read()
        elif isinstance(image_source, (bytes, bytearray)):
            image_bytes = bytes(image_source)
        else:
            logger.error('Invalid image_source type: %s', type(image_source))
            return _fallback_fields('Invalid image source provided')

        if not image_bytes:
            return _fallback_fields('Evidence file is empty')

        try:
            words = asyncio.run(self._run_ocr(image_bytes))
        except Exception as exc:
            logger.error('Windows OCR failed: %s', exc)
            return _fallback_fields(f'Windows OCR error: {exc}')

        if not words:
            return _fallback_fields('OCR returned no text')

        raw_text = ' | '.join(w['text'] for w in words)

        pair = self._extract_score(words, image_bytes)
        if pair is None:
            return _fallback_fields(f'OCR found no score pattern. Raw: {raw_text[:200]}')

        home, away, confidence = pair
        return [
            {'field': 'home_score', 'value': str(home), 'confidence': confidence,
             'source_region': 'home_side'},
            {'field': 'away_score', 'value': str(away), 'confidence': confidence,
             'source_region': 'away_side'},
            {'field': 'match_notes', 'value': f'WinRT local OCR raw text: {raw_text[:200]}',
             'confidence': confidence, 'source_region': 'full_image'},
        ]

    async def _run_ocr(self, image_bytes):
        with streams.InMemoryRandomAccessStream() as stream:
            writer = streams.DataWriter(stream)
            writer.write_bytes(image_bytes)
            await writer.store_async()
            stream.seek(0)
            decoder = await imaging.BitmapDecoder.create_async(stream)
            bitmap = await decoder.get_software_bitmap_async()

            engine = ocr.OcrEngine.try_create_from_user_profile_languages()
            if engine is None and ocr.OcrEngine.available_recognizer_languages:
                engine = ocr.OcrEngine.try_create_from_language(
                    ocr.OcrEngine.available_recognizer_languages[0]
                )
            if engine is None:
                raise RuntimeError('No OCR engine available for this user profile')

            result = await engine.recognize_async(bitmap)
            words = []
            for line in result.lines:
                for w in line.words:
                    b = w.bounding_rect
                    words.append({
                        'text': w.text,
                        'x': b.x,
                        'y': b.y,
                        'w': b.width,
                        'h': b.height,
                    })
            return words

    def _extract_score(self, words, image_bytes):
        rows = _cluster_rows(words)

        for row in sorted(rows, key=lambda r: r['top']):
            joined = ' '.join(w['text'] for w in sorted(row['words'], key=lambda w: w['x']))
            same_line_pair = _parse_pair(joined)
            if same_line_pair is not None:
                return same_line_pair[0], same_line_pair[1], 0.90

        digit_rows = []
        for row in rows:
            digits = [w for w in row['words'] if PURE_INT.match(w['text'])]
            if len(digits) >= 2:
                digit_rows.append((row, sorted(digits, key=lambda w: w['x'])))

        if not digit_rows:
            return None

        all_centers = [(r['top'] + r['bottom']) / 2 for r in rows if r['words']]
        median_center = sorted(all_centers)[len(all_centers) // 2] if all_centers else 0

        def row_score(row):
            center = (row['top'] + row['bottom']) / 2
            n = len([w for w in row['words'] if PURE_INT.match(w['text'])])
            return (0 if n == 2 else 1, abs(center - median_center))

        row, digits = min(digit_rows, key=lambda rd: row_score(rd[0]))

        home = int(digits[0]['text'])
        away = int(digits[-1]['text'])
        same_line = abs(digits[0]['y'] - digits[-1]['y']) < max(digits[0]['h'], digits[-1]['h']) * 0.5
        confidence = 0.90 if same_line else 0.60
        return home, away, confidence


def is_available():
    return WINRT_OCR_AVAILABLE