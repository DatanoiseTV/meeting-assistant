import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_config.dart';

abstract class SettingsRepository {
  Future<AppConfig> loadConfig();
  Future<void> saveConfig(AppConfig config);
}

class SettingsRepositoryImpl implements SettingsRepository {
  static const _configKey = 'app_config';
  final SharedPreferences _prefs;

  SettingsRepositoryImpl(this._prefs);

  @override
  Future<AppConfig> loadConfig() async {
    final jsonString = _prefs.getString(_configKey);
    if (jsonString == null) return const AppConfig();

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (e) {
      return const AppConfig();
    }
  }

  @override
  Future<void> saveConfig(AppConfig config) async {
    final jsonString = jsonEncode(config.toJson());
    await _prefs.setString(_configKey, jsonString);
  }
}
