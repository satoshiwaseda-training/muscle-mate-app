// 筋肉部位ビジュアライザー
/// CustomPainter で人体シルエットを描画し、
/// 鍛えた部位をアニメーション付きで「燃える」ように光らせる
import 'package:flutter/material.dart';

/// 筋肉グループ → 描画ゾーンのマッピング
const Map<String, List<String>> _muscleAliases = {
  'chest':      ['chest'],
  'back':       ['back'],
  'shoulders':  ['shoulders'],
  'biceps':     ['biceps'],
  'triceps':    ['triceps'],
  'legs':       ['quads', 'hamstrings'],
  'quads':      ['quads'],
  'hamstrings': ['hamstrings'],
  'glutes':     ['glutes'],
  'calves':     ['calves'],
  'core':       ['core'],
  'full_body':  ['chest','back','shoulders','biceps','triceps','quads','hamstrings','glutes','core'],
};

Set<String> _resolve(List<String> muscles) {
  final result = <String>{};
  for (final m in muscles) {
    result.addAll(_muscleAliases[m] ?? [m]);
  }
  return result;
}

class MuscleVisualizer extends StatefulWidget {
  final List<String> trainedMuscles; // MuscleGroup.value のリスト

  const MuscleVisualizer({super.key, required this.trainedMuscles});

  @override
  State<MuscleVisualizer> createState() => _MuscleVisualizerState();
}

class _MuscleVisualizerState extends State<MuscleVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trained = _resolve(widget.trainedMuscles);

    return Column(
      children: [
        // フロント / バック 切替
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _viewBtn('前面', true),
            const SizedBox(width: 12),
            _viewBtn('背面', false),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _glow,
          builder: (_, __) => SizedBox(
            width: 200,
            height: 340,
            child: CustomPaint(
              painter: _BodyPainter(
                trained: trained,
                glowIntensity: _glow.value,
                showFront: _showFront,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 凡例
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: _buildLegend(trained),
        ),
      ],
    );
  }

  Widget _viewBtn(String label, bool front) => GestureDetector(
        onTap: () => setState(() => _showFront = front),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _showFront == front
                ? const Color(0xFFE53935)
                : Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: _showFront == front ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold)),
        ),
      );

  List<Widget> _buildLegend(Set<String> trained) {
    final labels = {
      'chest': '胸', 'back': '背中', 'shoulders': '肩',
      'biceps': '二頭', 'triceps': '三頭', 'quads': '大腿四頭',
      'hamstrings': 'ハムスト', 'glutes': '臀部', 'core': '体幹', 'calves': 'ふくらはぎ',
    };
    return labels.entries.map((e) {
      final active = trained.contains(e.key);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFF6D00) : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(e.value,
              style: TextStyle(
                  fontSize: 11,
                  color: active ? const Color(0xFFFF6D00) : Colors.white38)),
        ],
      );
    }).toList();
  }
}

// ── CustomPainter ──────────────────────────────────────────────────────────

class _BodyPainter extends CustomPainter {
  final Set<String> trained;
  final double glowIntensity;
  final bool showFront;

  _BodyPainter({
    required this.trained,
    required this.glowIntensity,
    required this.showFront,
  });

  // 非アクティブ色
  static const _base = Color(0xFF37474F);
  // アクティブ色（グロー付き）
  Color get _hot => Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFFFF1744),
        glowIntensity,
      )!;

  Paint _paint(String zone) {
    final active = trained.contains(zone);
    if (!active) return Paint()..color = _base;
    return Paint()
      ..color = _hot
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 4 + 6 * glowIntensity);
  }

  Paint get _outline => Paint()
    ..color = Colors.white24
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 頭 ──────────────────────────────────────────────────
    final headR = w * 0.13;
    final headCenter = Offset(w / 2, h * 0.07);
    canvas.drawCircle(headCenter, headR, Paint()..color = _base);
    canvas.drawCircle(headCenter, headR, _outline);

    if (showFront) {
      _drawFront(canvas, w, h);
    } else {
      _drawBack(canvas, w, h);
    }
  }

  void _drawFront(Canvas canvas, double w, double h) {
    // ── 胸 ──────────────────────────────────────────────────
    _roundRect(canvas, Rect.fromLTRB(w*.25, h*.15, w*.75, h*.31),
        _paint('chest'), radius: 8);
    _roundRect(canvas, Rect.fromLTRB(w*.25, h*.15, w*.75, h*.31),
        _outline, radius: 8);

    // ── 肩 (左右) ────────────────────────────────────────────
    for (final x in [w*.12, w*.72]) {
      _roundRect(canvas, Rect.fromLTRB(x, h*.15, x+w*.16, h*.27),
          _paint('shoulders'), radius: 6);
      _roundRect(canvas, Rect.fromLTRB(x, h*.15, x+w*.16, h*.27),
          _outline, radius: 6);
    }

    // ── 体幹/腹 ──────────────────────────────────────────────
    _roundRect(canvas, Rect.fromLTRB(w*.28, h*.31, w*.72, h*.48),
        _paint('core'), radius: 6);
    _roundRect(canvas, Rect.fromLTRB(w*.28, h*.31, w*.72, h*.48),
        _outline, radius: 6);

    // ── 二頭筋 (左右) ────────────────────────────────────────
    for (final x in [w*.10, w*.76]) {
      _roundRect(canvas, Rect.fromLTRB(x, h*.27, x+w*.13, h*.42),
          _paint('biceps'), radius: 6);
      _roundRect(canvas, Rect.fromLTRB(x, h*.27, x+w*.13, h*.42),
          _outline, radius: 6);
    }

    // ── 前腕 (左右、三頭前面) ──────────────────────────────────
    for (final x in [w*.10, w*.76]) {
      _roundRect(canvas, Rect.fromLTRB(x, h*.42, x+w*.12, h*.55),
          Paint()..color = _base, radius: 5);
      _roundRect(canvas, Rect.fromLTRB(x, h*.42, x+w*.12, h*.55),
          _outline, radius: 5);
    }

    // ── 大腿四頭筋 (左右) ────────────────────────────────────
    for (final xOffset in [0.0, w*.27]) {
      _roundRect(canvas, Rect.fromLTRB(w*.23+xOffset, h*.50, w*.46+xOffset, h*.72),
          _paint('quads'), radius: 8);
      _roundRect(canvas, Rect.fromLTRB(w*.23+xOffset, h*.50, w*.46+xOffset, h*.72),
          _outline, radius: 8);
    }

    // ── ふくらはぎ (左右) ─────────────────────────────────────
    for (final xOffset in [0.0, w*.27]) {
      _roundRect(canvas, Rect.fromLTRB(w*.25+xOffset, h*.73, w*.45+xOffset, h*.92),
          _paint('calves'), radius: 6);
      _roundRect(canvas, Rect.fromLTRB(w*.25+xOffset, h*.73, w*.45+xOffset, h*.92),
          _outline, radius: 6);
    }
  }

  void _drawBack(Canvas canvas, double w, double h) {
    // ── 背中 (広背筋・僧帽筋) ─────────────────────────────────
    _roundRect(canvas, Rect.fromLTRB(w*.23, h*.15, w*.77, h*.42),
        _paint('back'), radius: 8);
    _roundRect(canvas, Rect.fromLTRB(w*.23, h*.15, w*.77, h*.42),
        _outline, radius: 8);

    // ── 肩 後ろ (左右) ──────────────────────────────────────
    for (final x in [w*.10, w*.72]) {
      _roundRect(canvas, Rect.fromLTRB(x, h*.15, x+w*.16, h*.27),
          _paint('shoulders'), radius: 6);
      _roundRect(canvas, Rect.fromLTRB(x, h*.15, x+w*.16, h*.27),
          _outline, radius: 6);
    }

    // ── 三頭筋 (左右) ────────────────────────────────────────
    for (final x in [w*.10, w*.76]) {
      _roundRect(canvas, Rect.fromLTRB(x, h*.27, x+w*.13, h*.42),
          _paint('triceps'), radius: 6);
      _roundRect(canvas, Rect.fromLTRB(x, h*.27, x+w*.13, h*.42),
          _outline, radius: 6);
    }

    // ── 臀部 ──────────────────────────────────────────────────
    _roundRect(canvas, Rect.fromLTRB(w*.24, h*.43, w*.76, h*.55),
        _paint('glutes'), radius: 8);
    _roundRect(canvas, Rect.fromLTRB(w*.24, h*.43, w*.76, h*.55),
        _outline, radius: 8);

    // ── ハムスト (左右) ──────────────────────────────────────
    for (final xOffset in [0.0, w*.27]) {
      _roundRect(canvas, Rect.fromLTRB(w*.23+xOffset, h*.55, w*.46+xOffset, h*.74),
          _paint('hamstrings'), radius: 8);
      _roundRect(canvas, Rect.fromLTRB(w*.23+xOffset, h*.55, w*.46+xOffset, h*.74),
          _outline, radius: 8);
    }

    // ── ふくらはぎ 後ろ ──────────────────────────────────────
    for (final xOffset in [0.0, w*.27]) {
      _roundRect(canvas, Rect.fromLTRB(w*.25+xOffset, h*.74, w*.45+xOffset, h*.92),
          _paint('calves'), radius: 6);
      _roundRect(canvas, Rect.fromLTRB(w*.25+xOffset, h*.74, w*.45+xOffset, h*.92),
          _outline, radius: 6);
    }
  }

  void _roundRect(Canvas canvas, Rect rect, Paint paint,
      {double radius = 8}) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint);
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.glowIntensity != glowIntensity ||
      old.trained != trained ||
      old.showFront != showFront;
}
