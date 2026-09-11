import os
import pytest

def test_voice_widget_code_and_disabled_fallback():
    voice_widget_file = os.path.join(os.getcwd(), 'mobile', 'lib', 'farmer', 'voice_assistant_widget.dart')
    assert os.path.exists(voice_widget_file)
    with open(voice_widget_file, 'r', encoding='utf-8') as f:
        content = f.read()
        assert 'Speech recognition unavailable' in content
        assert 'When is my turn' in content
        assert 'isSpeechAvailable = false' in content
