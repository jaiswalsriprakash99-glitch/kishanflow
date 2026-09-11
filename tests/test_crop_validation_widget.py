import os
import pytest

def test_crop_entry_widget_code_and_validation():
    crop_widget_file = os.path.join(os.getcwd(), 'mobile', 'lib', 'farmer', 'farmer_crop_screen.dart')
    assert os.path.exists(crop_widget_file)
    with open(crop_widget_file, 'r', encoding='utf-8') as f:
        content = f.read()
        assert 'Quantity is required' in content
        assert 'Please enter a valid positive quantity' in content
        assert 'Land area is required' in content
        assert 'Register Crop Details' in content

def test_profile_widget_offline_cache_code():
    profile_widget_file = os.path.join(os.getcwd(), 'mobile', 'lib', 'farmer', 'farmer_profile_screen.dart')
    assert os.path.exists(profile_widget_file)
    with open(profile_widget_file, 'r', encoding='utf-8') as f:
        content = f.read()
        assert 'Offline Mode - Cached at' in content
        assert 'Saved to local offline cache' in content
