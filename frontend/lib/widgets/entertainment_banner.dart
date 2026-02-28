// 総挙上重量エンタメバナー
/// グレードに応じた背景色と震えるようなアニメーション付き
import 'package:flutter/material.dart';

class EntertainmentBanner extends StatefulWidget {
  final Map<String, dynamic> data;
  const EntertainmentBanner({super.key, required this.data});

  @override
  State<EntertainmentBanner> createState() => _EntertainmentBannerState();
}

class _EntertainmentBannerState extends State<EntertainmentBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final grade = d['grade'] as String? ?? 'WARRIOR';
    final colorHex = d['grade_color'] as String? ?? '#69F0AE';
    final color = _hexColor(colorHex);
    final totalKg = (d['total_kg'] as num?)?.toDouble() ?? 0.0;
    final message = d['message'] as String? ?? '';

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // グレードバッジ
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                grade,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 2,
                    color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            // 総重量
            Text(
              '${totalKg.toStringAsFixed(0)} kg',
              style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -1),
            ),
            Text('総挙上重量',
                style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
            const SizedBox(height: 12),
            // 比喩メッセージ
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
