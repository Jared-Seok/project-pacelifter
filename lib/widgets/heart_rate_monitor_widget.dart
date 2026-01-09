import 'package:flutter/material.dart';
import '../services/heart_rate_service.dart';

class HeartRateMonitorWidget extends StatelessWidget {
  final HeartRateService hrService = HeartRateService();

  HeartRateMonitorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: hrService.heartRateStream,
      initialData: hrService.lastValue > 0 ? hrService.lastValue : null,
      builder: (context, snapshot) {
        final double bpm = snapshot.data ?? 0;
        final int zone = hrService.getHeartRateZone(bpm);
        final Color zoneColor = _getZoneColor(zone, context);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: zoneColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: zoneColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeartPulseIcon(color: zoneColor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        bpm > 0 ? bpm.toStringAsFixed(0) : '--',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'BPM',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (zone > 0)
                    Text(
                      'ZONE $zone',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: zoneColor,
                        letterSpacing: 1,
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

  Color _getZoneColor(int zone, BuildContext context) {
    switch (zone) {
      case 1: return Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8); // Deep Teal
      case 2: return Theme.of(context).colorScheme.tertiary; // Deep Teal
      case 3: return Theme.of(context).colorScheme.primary; // Neon Green
      case 4: return Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8); // Orange
      case 5: return Theme.of(context).colorScheme.secondary; // Orange
      default: return Colors.grey;
    }
  }
}

class _HeartPulseIcon extends StatefulWidget {
  final Color color;
  const _HeartPulseIcon({required this.color});

  @override
  State<_HeartPulseIcon> createState() => _HeartPulseIconState();
}

class _HeartPulseIconState extends State<_HeartPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(Icons.favorite, color: widget.color, size: 24),
    );
  }
}
