import os
from .base import BaseOCRProvider
from .placeholder import PlaceholderOCRProvider


def get_ocr_provider():
    mode = os.getenv('OCR_PROVIDER', 'auto').strip().lower()
    api_key = os.getenv('EXPLABS_API_KEY')

    def _experiential():
        try:
            from .experiential import ExperientialOCRProvider
            return ExperientialOCRProvider()
        except ImportError:
            return PlaceholderOCRProvider()

    def _windows():
        try:
            from .windows_ocr import WindowsOCRProvider, is_available
            if is_available():
                return WindowsOCRProvider()
        except ImportError:
            pass
        return PlaceholderOCRProvider()

    if mode == 'experiential':
        return _experiential() if api_key else _windows()
    if mode in ('local', 'windows'):
        return _windows()
    # auto: prefer free local, then paid, then placeholder
    try:
        from .windows_ocr import is_available
        if is_available():
            return _windows()
    except ImportError:
        pass
    return _experiential() if api_key else PlaceholderOCRProvider()