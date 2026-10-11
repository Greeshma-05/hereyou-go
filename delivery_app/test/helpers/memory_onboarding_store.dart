import 'dart:async';

import 'package:routerescue_partner/services/onboarding_store.dart';

class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore({this.completed = false});

  bool completed;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  Completer<void>? saveGate;

  @override
  Future<bool> isCompleted() async {
    if (failRead) throw StateError('Storage unavailable');
    return completed;
  }

  @override
  Future<void> complete() async {
    writes++;
    if (failWrite) throw StateError('Storage unavailable');
    if (saveGate != null) await saveGate!.future;
    completed = true;
  }
}
