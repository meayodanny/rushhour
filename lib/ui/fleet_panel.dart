import 'package:flutter/material.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';

class FleetPanel extends StatelessWidget {
  final GameEngine engine;

  const FleetPanel({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final lines = engine.lines;
        final selectedLine = lines.where((l) => l.id == engine.selectedLineId).firstOrNull ??
            (lines.isNotEmpty ? lines.first : null);

        final footReserve = engine.courierReserve[CourierType.foot] ?? 0;
        final bikeReserve = engine.courierReserve[CourierType.bike] ?? 0;
        final autoReserve = engine.courierReserve[CourierType.auto] ?? 0;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141417),
            border: Border(top: BorderSide(color: Color(0xFF2E2E35), width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Полоса резерва курьеров
              Row(
                children: [
                  const Text(
                    'РЕЗЕРВ ФЛОТА:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CourierBadge(label: '🚶 Пешие (вм.2)', count: footReserve),
                  const SizedBox(width: 6),
                  _CourierBadge(label: '🚲 Вело (вм.3)', count: bikeReserve),
                  const SizedBox(width: 6),
                  _CourierBadge(label: '🚗 Авто (вм.5)', count: autoReserve),
                ],
              ),

              const SizedBox(height: 8),

              // 2. Линии и управление курьерами
              if (lines.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Center(
                    child: Text(
                      '💡 Проведите пальцем между Рестораном (контур) и Районом (круг) по дорогам',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    // Список активных линий
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: lines.length,
                          itemBuilder: (context, idx) {
                            final line = lines[idx];
                            final isSelected = selectedLine?.id == line.id;
                            final lineCouriers = engine.couriers.where((c) => c.lineId == line.id).toList();

                            return GestureDetector(
                              onTap: () => engine.selectLine(line.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? line.color.withOpacity(0.35)
                                      : const Color(0xFF222226),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? line.color : Colors.white24,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: line.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Линия ${idx + 1}',
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${lineCouriers.length} курьер(а)',
                                          style: const TextStyle(color: Colors.white38, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    // Кнопка удаления линии
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                      onPressed: () => engine.deleteLine(line.id),
                                      tooltip: 'Удалить линию',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const VerticalDivider(color: Colors.white24, width: 12),

                    // Управление курьерами на выбранной линии
                    if (selectedLine != null)
                      Expanded(
                        flex: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              '+Курьер:',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            _AddCourierBtn(
                              icon: Icons.directions_walk,
                              count: footReserve,
                              onTap: footReserve > 0
                                  ? () => engine.assignCourierToLine(selectedLine.id, CourierType.foot)
                                  : null,
                              tooltip: 'Назначить пешего курьера',
                            ),
                            const SizedBox(width: 4),
                            _AddCourierBtn(
                              icon: Icons.directions_bike,
                              count: bikeReserve,
                              onTap: bikeReserve > 0
                                  ? () => engine.assignCourierToLine(selectedLine.id, CourierType.bike)
                                  : null,
                              tooltip: 'Назначить велокурьера',
                            ),
                            const SizedBox(width: 4),
                            _AddCourierBtn(
                              icon: Icons.directions_car,
                              count: autoReserve,
                              onTap: autoReserve > 0
                                  ? () => engine.assignCourierToLine(selectedLine.id, CourierType.auto)
                                  : null,
                              tooltip: 'Назначить автокурьера',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CourierBadge extends StatelessWidget {
  final String label;
  final int count;

  const _CourierBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0 ? const Color(0xFF2C2C32) : const Color(0xFF1E1E22),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: count > 0 ? const Color(0xFF4C4C58) : const Color(0xFF2A2A30),
          width: 0.8,
        ),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: count > 0 ? Colors.white : Colors.white30,
          fontSize: 10,
          fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _AddCourierBtn extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback? onTap;
  final String tooltip;

  const _AddCourierBtn({
    required this.icon,
    required this.count,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF2E323A) : const Color(0xFF1E2024),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? Colors.cyanAccent.withOpacity(0.6) : Colors.white12,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: enabled ? Colors.cyanAccent : Colors.white24,
              ),
              const SizedBox(width: 2),
              Text(
                '+',
                style: TextStyle(
                  color: enabled ? Colors.cyanAccent : Colors.white24,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
