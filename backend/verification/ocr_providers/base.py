from abc import ABC, abstractmethod


class BaseOCRProvider(ABC):
    @abstractmethod
    def extract(self, image_bytes):
        """
        Extract match data from screenshot.

        Returns:
            list of dict: [
                {
                    'field': 'home_score',
                    'value': '3',
                    'confidence': 0.95,
                    'source_region': 'scoreboard_center'
                },
                ...
            ]
        """
        pass

    @abstractmethod
    def get_provider_name(self):
        pass