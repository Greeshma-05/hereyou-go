import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/user_repository.dart';
import '../models/journey_model.dart';

class JourneyProvider extends ChangeNotifier {
  JourneyProvider({this.repository, this.uid}) {
    loading = cloudBacked;
    if (cloudBacked) {
      _subscription = repository!
          .watchJourneys(uid!)
          .listen(
            (values) {
              _history = values;
              _journey = values.isEmpty ? null : values.first.journey;
              loading = false;
              error = null;
              _notify();
            },
            onError: (Object failure) {
              loading = false;
              error = 'Travel history could not sync. Check your connection.';
              _notify();
            },
          );
    }
  }
  final UserRepository? repository;
  final String? uid;
  StreamSubscription<List<SavedJourney>>? _subscription;
  Journey? _journey;
  Journey? get journey => _journey;
  JourneyMode? _searchMode;
  JourneyMode get searchMode =>
      _searchMode ?? _journey?.mode ?? JourneyMode.bus;
  void setSearchMode(JourneyMode value) {
    _searchMode = value;
    _notify();
  }

  List<SavedJourney> _history = [];
  List<SavedJourney> get history => List.unmodifiable(_history);
  bool get cloudBacked => uid != null && repository != null;
  bool loading = false;
  bool _disposed = false;
  String? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> save(Journey value) {
    if (!value.isValid) throw ArgumentError('Complete all journey details.');
    return _save(value);
  }

  Future<void> _save(Journey value) async {
    final now = DateTime.now();
    final saved = SavedJourney(
      id: 'trip-${now.microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
      journey: value,
      savedAt: now,
    );
    if (cloudBacked) await repository!.saveJourney(uid!, saved);
    if (_disposed) return;
    _journey = value;
    _searchMode = null;
    _history = [saved, ..._history.where((j) => j.id != saved.id)];
    error = null;
    _notify();
  }

  void clear() {
    _journey = null;
    _searchMode = null;
    _history = [];
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
