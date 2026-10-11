import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingStore {
  Future<bool> isCompleted();
  Future<void> complete();
}

class LocalOnboardingStore implements OnboardingStore {
  static const completedKey = 'onboarding_completed';
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<bool> isCompleted() async {
    return await _preferences.getBool(completedKey) ?? false;
  }

  @override
  Future<void> complete() => _preferences.setBool(completedKey, true);
}
