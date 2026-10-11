import 'dart:async';
import '../data/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider(this._storage, {this.repository, this.uid}) {
    if (cloudBacked) {
      _subscription = repository!
          .watchPreferences(uid!)
          .listen(
            (value) {
              notifications = value.notifications;
              _checklist
                ..clear()
                ..addAll(value.checklist);
              error = null;
              if (!_disposed) notifyListeners();
            },
            onError: (Object failure) {
              error = 'Preferences could not sync. Check your connection.';
              if (!_disposed) notifyListeners();
            },
          );
      return;
    }
    notifications = _storage?.getBool('notifications') ?? false;
    _checklist.addAll(_storage?.getStringList('checklist') ?? []);
  }
  final SharedPreferences? _storage;
  final UserRepository? repository;
  final String? uid;
  StreamSubscription<SavedPreferences>? _subscription;
  bool _disposed = false;
  bool get cloudBacked => uid != null && repository != null;
  bool notifications = false;
  String? error;
  final Set<String> _checklist = {};
  bool checked(String item) => _checklist.contains(item);
  bool get storageAvailable => cloudBacked || _storage != null;
  Future<void> setNotifications(bool value) async {
    notifications = value;
    notifyListeners();
    await _save();
  }

  Future<void> toggle(String item) async {
    if (!_checklist.add(item)) _checklist.remove(item);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      if (cloudBacked) {
        await repository!.savePreferences(
          uid!,
          SavedPreferences(
            notifications: notifications,
            checklist: _checklist.toList(),
          ),
        );
        error = null;
        if (!_disposed) notifyListeners();
        return;
      }
      if (_storage == null) throw StateError('Storage unavailable');
      final results = await Future.wait([
        _storage.setBool('notifications', notifications),
        _storage.setStringList('checklist', _checklist.toList()),
      ]);
      error = results.every((ok) => ok)
          ? null
          : 'Preferences could not be saved.';
    } catch (_) {
      error = cloudBacked
          ? 'Preferences could not sync. Try again when connected.'
          : 'Preferences are available for this session only.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
