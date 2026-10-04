import 'package:flutter/material.dart';
import '../engine/game_engine.dart';

class GameHud extends StatelessWidget {
  final GameEngine engine;

  const GameHud({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final clock = engine.gameClock;
        final isRush = clock.isRushHour;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Верхняя полоса статуса
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2E2E35), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Блок календаря и времени
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRush ? const Color(0xFFFF9800) : const Color(0xFF3C3C44),
                        width: isRush ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          size: 16,
                          color: isRush ? const Color(0xFFFF9800) : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${clock.dayName}, Д${clock.day}  ${clock.formattedTime}',
                          style: TextStyle(
                            color: isRush ? const Color(0xFFFFB74D) : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Панель контроля времени (Пауза, 1x, 2.5x)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF222226),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _SpeedButton(
                          icon: Icons.pause,
                          label: '',
                          isActive: engine.timeMultiplier == 0.0,
                          onTap: () => engine.setTimeMultiplier(0.0),
                          tooltip: 'Пауза (||)',
                        ),
                        _SpeedButton(
                          icon: Icons.play_arrow,
                          label: '1x',
                          isActive: engine.timeMultiplier == 1.0,
                          onTap: () => engine.setTimeMultiplier(1.0),
                          tooltip: 'Обычная скорость (>)',
                        ),
                        _SpeedButton(
                          icon: Icons.fast_forward,
                          label: '2.5x',
                          isActive: engine.timeMultiplier > 1.0,
                          onTap: () => engine.setTimeMultiplier(2.5),
                          tooltip: 'Ускорение (>>)',
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Индикатор слотов линий
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.route, size: 15, color: Colors.cyanAccent),
                        const SizedBox(width: 5),
                        Text(
                          '${engine.lines.length}/${engine.maxLines}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Счет доставок
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2816),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFFFFD54F)),
                        const SizedBox(width: 5),
                        Text(
                          '${engine.score}',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Баннер пикового времени или уведомлений
            if (isRush || engine.bannerMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                color: engine.bannerMessage != null
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE65100),
                child: Text(
                  engine.bannerMessage ??
                      (clock.isEveningPeak
                          ? '🔥 ВЕЧЕРНИЙ ПИК (18:00–21:00) — Заказы поступают в 2 раза чаще!'
                          : '🎉 ВЫХОДНОЙ ДЕНЬ — Повышенный спрос на доставку!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const _SpeedButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? Colors.white : Colors.white38,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
