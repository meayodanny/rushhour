import 'package:flutter/material.dart';
import '../engine/game_engine.dart';

class GameOverOverlay extends StatelessWidget {
  final GameEngine engine;

  const GameOverOverlay({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        if (!engine.isGameOver) return const SizedBox.shrink();

        return Container(
          color: Colors.black.withOpacity(0.85),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF5252), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1744).withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Color(0xFFFF5252),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'КОЛЛАПС СЕТИ',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Один из районов переполнился заказами (9+) и время разгрузки (30с) истекло!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Карточка статистики
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF33333E)),
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                          label: '⭐ Доставлено заказов:',
                          value: '${engine.score}',
                          valueColor: const Color(0xFFFFD54F),
                        ),
                        const Divider(color: Color(0xFF282830), height: 16),
                        _StatRow(
                          label: '📅 Прожито дней:',
                          value: '${engine.gameClock.day} дн. (${engine.gameClock.formattedTime})',
                          valueColor: Colors.white,
                        ),
                        const Divider(color: Color(0xFF282830), height: 16),
                        _StatRow(
                          label: '🚇 Построено линий:',
                          value: '${engine.lines.length} / ${engine.maxLines}',
                          valueColor: Colors.cyanAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Кнопка рестарта
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF1744),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () => engine.restartGame(),
                      icon: const Icon(Icons.replay, size: 20),
                      label: const Text(
                        'НАЧАТЬ ЗАНОВО',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
