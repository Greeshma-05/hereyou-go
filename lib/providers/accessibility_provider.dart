import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/accessibility_settings.dart';

/// Device preferences stay available offline and across sign-in/sign-out.
class AccessibilityProvider extends ChangeNotifier {
  AccessibilityProvider(this._storage) {
    try {
      final raw = _storage?.getString(storageKey);
      if (raw == null) return;
      final value = jsonDecode(raw) as Map<String, dynamic>;
      _readingFont = value['readingFont'] == true;
      _colorTheme = AppColorTheme.values.firstWhere(
        (theme) => theme.name == value['colorTheme'],
        orElse: () => AppColorTheme.lime,
      );
      _readingSize = ReadingSize.values.firstWhere(
        (size) => size.name == value['readingSize'],
        orElse: () => ReadingSize.standard,
      );
    } catch (_) {
      // An older or damaged preference must not prevent the app from opening.
    }
  }

  static const storageKey = 'accessibility.v1';
  final SharedPreferences? _storage;
  bool _readingFont = false;
  AppColorTheme _colorTheme = AppColorTheme.lime;
  ReadingSize _readingSize = ReadingSize.standard;
  Future<void> _pendingSave = Future.value();
  bool _disposed = false;
  String? error;

  bool get readingFont => _readingFont;
  AppColorTheme get colorTheme => _colorTheme;
  ReadingSize get readingSize => _readingSize;

  Future<void> setReadingFont(bool value) {
    _readingFont = value;
    return _save();
  }

  Future<void> setColorTheme(AppColorTheme value) {
    _colorTheme = value;
    return _save();
  }

  Future<void> setReadingSize(ReadingSize value) {
    _readingSize = value;
    return _save();
  }

  Future<void> reset() {
    _readingFont = false;
    _colorTheme = AppColorTheme.lime;
    _readingSize = ReadingSize.standard;
    return _save();
  }

  Future<void> _save() {
    final encoded = jsonEncode({
      'readingFont': _readingFont,
      'colorTheme': _colorTheme.name,
      'readingSize': _readingSize.name,
    });
    notifyListeners();
    // Serialize writes so rapid choices cannot restore an older selection.
    _pendingSave = _pendingSave.then((_) async {
      try {
        final saved = await _storage?.setString(storageKey, encoded) ?? false;
        error = saved ? null : 'Changes will last for this session only.';
      } catch (_) {
        error = 'Changes will last for this session only.';
      }
      if (!_disposed) notifyListeners();
    });
    return _pendingSave;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
