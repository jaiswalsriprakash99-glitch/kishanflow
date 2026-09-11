import os
import json
import pytest

def test_mobile_app_structure():
    mobile_dir = os.path.join(os.getcwd(), 'mobile')
    assert os.path.exists(os.path.join(mobile_dir, 'pubspec.yaml'))
    assert os.path.exists(os.path.join(mobile_dir, 'l10n.yaml'))
    assert os.path.exists(os.path.join(mobile_dir, 'lib', 'main.dart'))
    assert os.path.exists(os.path.join(mobile_dir, 'lib', 'app.dart'))

def test_role_based_screens_exist():
    lib_dir = os.path.join(os.getcwd(), 'mobile', 'lib')
    assert os.path.exists(os.path.join(lib_dir, 'farmer', 'farmer_shell.dart'))
    assert os.path.exists(os.path.join(lib_dir, 'staff', 'staff_shell.dart'))
    assert os.path.exists(os.path.join(lib_dir, 'pacs', 'pacs_shell.dart'))
    assert os.path.exists(os.path.join(lib_dir, 'admin', 'admin_shell.dart'))

def test_arb_localizations_completeness():
    l10n_dir = os.path.join(os.getcwd(), 'mobile', 'lib', 'l10n')
    locales = ['en', 'hi', 'kn', 'mr', 'te']
    required_keys = {'welcome', 'appTitle', 'splashSubtitle', 'selectRole', 'farmerRole', 'staffRole', 'pacsRole', 'adminRole'}

    for loc in locales:
        arb_path = os.path.join(l10n_dir, f'app_{loc}.arb')
        assert os.path.exists(arb_path), f"Missing ARB file for {loc}"
        with open(arb_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            for key in required_keys:
                assert key in data, f"Missing key '{key}' in app_{loc}.arb"

def test_widget_test_file_exists():
    widget_test_path = os.path.join(os.getcwd(), 'mobile', 'test', 'widget_test.dart')
    assert os.path.exists(widget_test_path)
    with open(widget_test_path, 'r', encoding='utf-8') as f:
        content = f.read()
        assert 'Welcome to KisanFlow' in content
        assert 'किसानफ़्लो में आपका स्वागत है' in content
