import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/entities.dart';

class PersistenceService {
  static const String _settingsName = 'settingsBox';
  static const String _statsName = 'statsBox';
  static const String _sessionName = 'sessionBox';

  late Box<Object?> settings;
  late Box<Object?> stats;
  late Box<Object?> session;

  Future<void> initialize() async {
    await Hive.initFlutter();
    settings = await Hive.openBox<Object?>(_settingsName);
    stats = await Hive.openBox<Object?>(_statsName);
    session = await Hive.openBox<Object?>(_sessionName);
  }

  /// Remains true until the first tutorial run reaches its result screen and
  /// the player explicitly returns to the menu.
  bool get isFirstLaunch => settings.get('isFirstLaunch', defaultValue: true) == true;
  Future<void> completeFirstLaunch() => settings.put('isFirstLaunch', false);

  bool tutorialSeen(String key) => settings.get('tutorial_$key', defaultValue: false) == true;
  Future<void> markTutorialSeen(String key) => settings.put('tutorial_$key', true);

  Future<void> resetTutorial() async {
    final tutorialKeys = settings.keys
        .whereType<String>()
        .where((String key) => key.startsWith('tutorial_'))
        .toList();
    for (final key in tutorialKeys) {
      await settings.delete(key);
    }
  }

  String get language => settings.get('language', defaultValue: 'system')! as String;
  Future<void> setLanguage(String value) => settings.put('language', value);
  bool get audioEnabled => settings.get('audio', defaultValue: true) == true;
  Future<void> setAudioEnabled(bool value) => settings.put('audio', value);

  Future<void> saveSession(GameSnapshot snapshot) => session.put('active', jsonEncode(snapshot.toJson()));
  GameSnapshot? loadSession() {
    final value = session.get('active');
    if (value is! String) return null;
    try {
      return GameSnapshot.fromJson(jsonDecode(value) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  Future<void> clearSession() => session.delete('active');

  Future<void> saveRecord(String cityId, Difficulty difficulty, int score, double survival, int networkSize) async {
    final key = '${cityId}_${difficulty.name}';
    final existing = stats.get(key);
    var best = 0;
    if (existing is String) {
      final decoded = jsonDecode(existing) as Map<String, Object?>;
      best = (decoded['deliveries']! as num).toInt();
    }
    if (score >= best) {
      await stats.put(key, jsonEncode(<String, Object?>{
        'deliveries': score,
        'survivalTime': survival,
        'networkSize': networkSize,
      }));
    }
  }
}
