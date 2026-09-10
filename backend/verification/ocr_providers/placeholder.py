from .base import BaseOCRProvider


class PlaceholderOCRProvider(BaseOCRProvider):
    """
    Placeholder OCR — returns simulated extraction.
    Replace this with real AI/OCR provider (Tesseract, Google Vision, AWS Textract).
    """

    def get_provider_name(self):
        return 'placeholder_v1'

    def extract(self, image_bytes):
        return [
            {
                'field': 'home_score',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'away_score',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'home_possession',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'away_possession',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'home_shots',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'away_shots',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'home_shots_on_target',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'away_shots_on_target',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'home_name',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
            {
                'field': 'away_name',
                'value': None,
                'confidence': 0.0,
                'source_region': 'not_available',
            },
        ]