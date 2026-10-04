import 'package:flutter/material.dart';
import 'engine/game_engine.dart';
import 'painters/background_painter.dart';
import 'painters/game_painter.dart';

void main() {
  runApp(const DeliveryMetroApp());
}

class DeliveryMetroApp extends StatelessWidget {
  const DeliveryMetroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameEngine _engine;

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
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            // Игровое поле с фиксированными пропорциями для идеальной работы сетки
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
                          RepaintBoundary(
                            child: CustomPaint(
                              isComplex: true,
                              painter: BackgroundPainter(),
                              size: const Size(400, 800),
                            ),
                          ),
                          GestureDetector(
                            onPanStart: _engine.onPanStart,
                            onPanUpdate: _engine.onPanUpdate,
                            onPanEnd: _engine.onPanEnd,
                            child: CustomPaint(
                              painter: GamePainter(_engine),
                              size: const Size(400, 800),
                            ),
                          ),
                          ListenableBuilder(
                            listenable: _engine,
                            builder: (context, _) {
                              if (!_engine.isGameOver) return const SizedBox.shrink();
                              return Container(
                                color: Colors.black87,
                                child: Center(
                                  child: Text(
                                    'Коллапс службы доставки\nСчет: ${_engine.score}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Панель управления и корректировки линий
            Container(
              height: 100,
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Row(
                children: [
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _engine,
                      builder: (context, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Счет: ${_engine.score}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Активные линии (Нажмите для отмены):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _engine.lines.length,
                                itemBuilder: (context, index) {
                                  final line = _engine.lines[index];
                                  return GestureDetector(
                                    onTap: () => _engine.deleteLine(line.id),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8, top: 4),
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: line.color.withOpacity(0.3),
                                        border: Border.all(color: line.color, width: 2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}