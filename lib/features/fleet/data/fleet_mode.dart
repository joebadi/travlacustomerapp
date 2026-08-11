import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide individual/fleet mode. Persisted so the choice survives restarts.
/// In fleet mode the More menu exposes the fleet-organisation tools.
class FleetModeNotifier extends Notifier<bool> {
  static const _key = 'fleet_mode_enabled';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final fleetModeProvider = NotifierProvider<FleetModeNotifier, bool>(FleetModeNotifier.new);
