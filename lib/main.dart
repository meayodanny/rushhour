import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/flowline_app.dart';
import 'game/game_controller.dart';
import 'models/city.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/persistence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  final persistence = PersistenceService(); await persistence.initialize();
  final city = await CityData.load('rivergate');
  final audio = AudioService(enabled: persistence.audioEnabled);
  try { await audio.preload(); } on Object { /* Audio remains optional on unsupported test platforms. */ }
  final ads = AdService();
  try { await ads.initialize(); } on Object { /* The game remains playable when ad services are unavailable. */ }
  runApp(ProviderScope(overrides: [
    persistenceProvider.overrideWithValue(persistence), cityProvider.overrideWithValue(city),
    audioServiceProvider.overrideWithValue(audio), adServiceProvider.overrideWithValue(ads),
  ], child: const FlowlineApp()));
}
