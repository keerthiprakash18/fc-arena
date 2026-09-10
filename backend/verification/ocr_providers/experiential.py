import base64
import json
import os
import re
import logging

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "You are an expert OCR engine for FC Arena, an eSports competitive gaming platform. "
    "You analyze post-match result screenshots from mobile games. "
    "Extract ONLY the final match score and overall confidence. "
    "Return STRICT JSON with NO markdown, NO code fences, NO extra text:\n"
    '{"home_score": <int or null>, "away_score": <int or null>, '
    '"confidence": <float 0.0-1.0>, "notes": "<brief description of what you see>"}'
)


def _make_extractors(home_score, away_score, overall_confidence, notes):
    fields = []
    if home_score is not None:
        fields.append({
            'field': 'home_score',
            'value': str(home_score),
            'confidence': float(overall_confidence),
            'source_region': 'home_side',
        })
    else:
        fields.append({
            'field': 'home_score',
            'value': None,
            'confidence': 0.0,
            'source_region': 'home_side',
        })

    if away_score is not None:
        fields.append({
            'field': 'away_score',
            'value': str(away_score),
            'confidence': float(overall_confidence),
            'source_region': 'away_side',
        })
    else:
        fields.append({
            'field': 'away_score',
            'value': None,
            'confidence': 0.0,
            'source_region': 'away_side',
        })

    fields.append({
        'field': 'match_notes',
        'value': notes or '',
        'confidence': float(overall_confidence),
        'source_region': 'full_image',
    })
    return fields


def _parse_json_response(text):
    text = text.strip()
    text = re.sub(r'^```(?:json)?\s*', '', text)
    text = re.sub(r'\s*```$', '', text)

    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        pass

    match = re.search(r'\{[^{}]+\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except (json.JSONDecodeError, ValueError):
            pass

    return None


class ExperientialOCRProvider:
    def __init__(self, api_key=None, base_url=None, model=None):
        self.api_key = api_key or os.getenv('EXPLABS_API_KEY')
        self.base_url = (base_url or os.getenv('EXPLABS_BASE_URL', 'https://api.experientiallabs.ai/v1')).rstrip('/')
        self.model = model or os.getenv('EXPLABS_MODEL', 'claude-fable-5.1')

    def get_provider_name(self):
        return 'experiential'

    def extract(self, image_source):
        import httpx

        if not self.api_key:
            logger.warning('EXPLABS_API_KEY not configured — returning zero-confidence fallback')
            return _make_extractors(None, None, 0.0, 'Experiential API key not configured')

        if isinstance(image_source, (str, os.PathLike)):
            image_source = os.fspath(image_source)
            if not os.path.exists(image_source):
                logger.error('Evidence file not found: %s', image_source)
                return _make_extractors(None, None, 0.0, f'Evidence file not found: {image_source}')
            with open(image_source, 'rb') as f:
                image_bytes = f.read()
        elif isinstance(image_source, (bytes, bytearray)):
            image_bytes = bytes(image_source)
        else:
            logger.error('Invalid image_source type: %s', type(image_source))
            return _make_extractors(None, None, 0.0, 'Invalid image source provided')

        if len(image_bytes) == 0:
            return _make_extractors(None, None, 0.0, 'Evidence file is empty')

        b64 = base64.b64encode(image_bytes).decode('utf-8')

        payload = {
            'model': self.model,
            'messages': [
                {
                    'role': 'system',
                    'content': SYSTEM_PROMPT,
                },
                {
                    'role': 'user',
                    'content': [
                        {
                            'type': 'text',
                            'text': (
                                'Analyze this FC Arena match result screenshot. '
                                'Extract the final home and away scores. '
                                'Return ONLY the JSON response as specified in the system prompt.'
                            ),
                        },
                        {
                            'type': 'image_url',
                            'image_url': {
                                'url': f'data:image/png;base64,{b64}',
                            },
                        },
                    ],
                },
            ],
            'temperature': 0,
            'max_tokens': 500,
        }

        try:
            client = httpx.Client(timeout=60.0)
            response = client.post(
                f'{self.base_url}/chat/completions',
                json=payload,
                headers={
                    'Authorization': f'Bearer {self.api_key}',
                    'Content-Type': 'application/json',
                },
            )
            client.close()
        except httpx.TimeoutException:
            logger.warning('Experiential API timeout — falling back')
            return _make_extractors(None, None, 0.0, 'Experiential API request timed out')
        except httpx.RequestError as exc:
            logger.error('Experiential API request error: %s', exc)
            return _make_extractors(None, None, 0.0, f'Experiential API connection error: {exc}')
        except Exception as exc:
            logger.error('Unexpected error calling Experiential API: %s', exc)
            return _make_extractors(None, None, 0.0, f'Unexpected API error: {exc}')

        if response.status_code != 200:
            try:
                err = response.json()
                msg = err.get('error', {}).get('message', response.text[:300])
            except Exception:
                msg = response.text[:300]
            logger.warning('Experiential API %d error: %s', response.status_code, msg)
            return _make_extractors(None, None, 0.0, f'Experiential API error ({response.status_code}): {msg}')

        try:
            body = response.json()
            content = body['choices'][0]['message']['content']
        except (KeyError, IndexError, TypeError) as exc:
            logger.error('Failed to parse Experiential response structure: %s', exc)
            return _make_extractors(None, None, 0.0, f'Invalid response structure: {exc}')

        parsed = _parse_json_response(content)
        if parsed is None:
            logger.warning('Could not parse JSON from Experiential response: %s', content[:200])
            return _make_extractors(None, None, 0.0, f'Could not parse model output as JSON: {content[:200]}')

        home = parsed.get('home_score')
        away = parsed.get('away_score')
        conf = float(parsed.get('confidence', 0) or 0)
        conf = max(0.0, min(1.0, conf))
        notes = parsed.get('notes', '') or ''

        try:
            if home is not None:
                home = int(home)
            if away is not None:
                away = int(away)
        except (ValueError, TypeError):
            logger.warning('Non-integer scores returned: home=%s away=%s', home, away)
            conf = min(conf, 0.3)

        return _make_extractors(home, away, conf, notes)
