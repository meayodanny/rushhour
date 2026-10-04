import 'package:flutter/material.dart';
import 'engine/game_engine.dart';
import 'painters/background_painter.dart';
import 'painters/game_painter.dart';
import 'ui/fleet_panel.dart';
import 'ui/game_over_dialog.dart';
import 'ui/hud.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryMetroApp());
}

class DeliveryMetroApp extends StatelessWidget {
  const DeliveryMetroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Логистическая Стратегия Мегаполиса',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141416),
        primaryColor: const Color(0xFF1E88E5),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.start();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141416),
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель: Часы, Контроль скорости (||, >, >>), Слоты линий и Счет
            GameHud(engine: _engine),

            // Игровое поле с фиксированными пропорциями (400x800)
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 400 / 800,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 400,
                      height: 800,
                      child: Stack(
                        children: [
                          // 1. Статический слой фона (кэшируется в GPU)
                          RepaintBoundary(
                            child: CustomPaint(
                              isComplex: true,
                              painter: BackgroundPainter(),
                              size: const Size(400, 800),
                            ),
                          ),

                          // 2. Динамический интерактивный слой игры
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _engine.onPanStart,
                            onPanUpdate: _engine.onPanUpdate,
                            onPanEnd: _engine.onPanEnd,
                            child: CustomPaint(
                              painter: GamePainter(_engine),
                              size: const Size(400, 800),
                            ),
                          ),

                          // 3. Оверлей поражения (Game Over)
                          GameOverOverlay(engine: _engine),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Нижняя панель: Управление линиями и курьерским флотом (Пешие/Вело/Авто)
            FleetPanel(engine: _engine),
          ],
        ),
      ),
    );
  }
}
