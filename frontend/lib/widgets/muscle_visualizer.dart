// 筋肉部位ビジュアライザー v2
// ─────────────────────────────────────────────────────────────────────────────
// 変更点:
//   - 矩形(Rect)から解剖学的ベジェ曲線パスに刷新
//   - 強度 0.0〜1.0 に基づく 5段階ヒートマップカラー (冷→熱)
//   - 強度に比例した「筋肉の膨張」アニメーション (scaleTransform)
//   - /visualizer/heatmap API から取得した intensity データを直接受け取れる
//   - BIG3 進捗バー (bench_current/bench_goal) を下部に表示
// ─────────────────────────────────────────────────────────────────────────────
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

// ── ヒートマップカラー (Blender スクリプトと同じ変換ロジック) ─────────────

Color _intensityToColor(double intensity, double glowPhase) {
  // glowPhase: 0.0〜1.0 のアニメーション位相
  final Color base;
  if (intensity < 0.25) {
    base = Color.lerp(
      const Color(0xFF1A1A2E), // ほぼ黒
      const Color(0xFF16213E), // ダークネイビー
      intensity / 0.25,
    )!;
  } else if (intensity < 0.55) {
    base = Color.lerp(
      const Color(0xFF0F3460), // ディープブルー
      const Color(0xFFFF6D00), // オレンジ
      (intensity - 0.25) / 0.30,
    )!;
  } else if (intensity < 0.80) {
    base = Color.lerp(
      const Color(0xFFFF6D00), // オレンジ
      const Color(0xFFFF1744), // レッド
      (intensity - 0.55) / 0.25,
    )!;
  } else {
    base = Color.lerp(
      const Color(0xFFFF1744), // レッド
      const Color(0xFFFFFFFF), // ホワイトホット
      (intensity - 0.80) / 0.20,
    )!;
  }

  // グロー位相でわずかに輝度を変動させる
  if (intensity < 0.3) return base;
  final glow = 0.85 + 0.15 * glowPhase;
  return Color.fromARGB(
    base.alpha,
    (base.red   * glow).clamp(0, 255).toInt(),
    (base.green * glow).clamp(0, 255).toInt(),
    (base.blue  * glow).clamp(0, 255).toInt(),
  );
}

// 強度に応じたブラーサイズ (筋肉の「発光感」)
double _blurRadius(double intensity) => intensity < 0.3 ? 0.0 : 3.0 + intensity * 9.0;

// 強度に応じた膨張スケール (1.0〜1.12)
double _pumpScale(double intensity) => 1.0 + intensity * 0.12;


// ─────────────────────────────────────────────────────────────────────────────

class MuscleVisualizer extends StatefulWidget {
  /// MuscleGroup.value のリスト (後方互換モード)
  final List<String> trainedMuscles;

  /// /visualizer/heatmap から取得した強度マップ (0.0〜1.0)
  /// 指定した場合 trainedMuscles より優先される
  final Map<String, double>? intensityMap;

  /// BIG3 進捗バー表示用
  final double? benchCurrent;
  final double? benchGoal;
  final double? squatCurrent;
  final double? squatGoal;
  final double? deadliftCurrent;
  final double? deadliftGoal;

  const MuscleVisualizer({
    super.key,
    required this.trainedMuscles,
    this.intensityMap,
    this.benchCurrent,
    this.benchGoal,
    this.squatCurrent,
    this.squatGoal,
    this.deadliftCurrent,
    this.deadliftGoal,
  });

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
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 最終的に使う intensity マップを解決する
  Map<String, double> get _effectiveIntensity {
    if (widget.intensityMap != null) return widget.intensityMap!;
    // trainedMuscles から 0.0/1.0 の二値マップを生成
    final trained = _resolve(widget.trainedMuscles);
    return {
      'chest':      trained.contains('chest')      ? 1.0 : 0.0,
      'back':       trained.contains('back')        ? 1.0 : 0.0,
      'shoulders':  trained.contains('shoulders')   ? 1.0 : 0.0,
      'biceps':     trained.contains('biceps')      ? 1.0 : 0.0,
      'triceps':    trained.contains('triceps')     ? 1.0 : 0.0,
      'quads':      trained.contains('quads')       ? 1.0 : 0.0,
      'hamstrings': trained.contains('hamstrings')  ? 1.0 : 0.0,
      'glutes':     trained.contains('glutes')      ? 1.0 : 0.0,
      'calves':     trained.contains('calves')      ? 1.0 : 0.0,
      'core':       trained.contains('core')        ? 1.0 : 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
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
          builder: (_, __) {
            final intensities = _effectiveIntensity;
            return SizedBox(
              width: 220,
              height: 370,
              child: CustomPaint(
                painter: _AnatomicalBodyPainter(
                  intensities: intensities,
                  glowPhase: _glow.value,
                  showFront: _showFront,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // BIG3 進捗バー
        if (_hasBig3Progress()) _big3ProgressSection(),
        const SizedBox(height: 12),
        // 凡例
        AnimatedBuilder(
          animation: _glow,
          builder: (_, __) {
            final intensities = _effectiveIntensity;
            return Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _buildLegend(intensities),
            );
          },
        ),
      ],
    );
  }

  bool _hasBig3Progress() =>
      widget.benchCurrent != null ||
      widget.squatCurrent != null ||
      widget.deadliftCurrent != null;

  Widget _big3ProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BIG3 進捗',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.benchCurrent != null)
            _progressBar('ベンチ', widget.benchCurrent!, widget.benchGoal,
                const Color(0xFFFF1744)),
          if (widget.squatCurrent != null)
            _progressBar('スクワット', widget.squatCurrent!, widget.squatGoal,
                const Color(0xFFFF6D00)),
          if (widget.deadliftCurrent != null)
            _progressBar('デッドリフト', widget.deadliftCurrent!, widget.deadliftGoal,
                const Color(0xFFFFD600)),
        ],
      ),
    );
  }

  Widget _progressBar(String label, double current, double? goal, Color color) {
    final ratio = (goal != null && goal > 0) ? (current / goal).clamp(0.0, 1.0) : 0.8;
    final pct = (ratio * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.6), color],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            goal != null ? '${current.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}kg' : '${current.toStringAsFixed(0)}kg',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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

  List<Widget> _buildLegend(Map<String, double> intensities) {
    final labels = {
      'chest': '胸', 'back': '背中', 'shoulders': '肩',
      'biceps': '二頭', 'triceps': '三頭', 'quads': '大腿四頭',
      'hamstrings': 'ハムスト', 'glutes': '臀部', 'core': '体幹', 'calves': 'ふくらはぎ',
    };
    return labels.entries.map((e) {
      final intensity = intensities[e.key] ?? 0.0;
      final active = intensity > 0.05;
      final color = active
          ? _intensityToColor(intensity, _glow.value)
          : Colors.white24;
      final pctStr = active ? ' ${(intensity * 100).toStringAsFixed(0)}%' : '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text('${e.value}$pctStr',
              style: TextStyle(fontSize: 11, color: active ? color : Colors.white38)),
        ],
      );
    }).toList();
  }
}


// ── 解剖学的 CustomPainter ────────────────────────────────────────────────────

class _AnatomicalBodyPainter extends CustomPainter {
  final Map<String, double> intensities;
  final double glowPhase;
  final bool showFront;

  _AnatomicalBodyPainter({
    required this.intensities,
    required this.glowPhase,
    required this.showFront,
  });

  static const _baseSkin = Color(0xFF2E2E3A);

  double _i(String key) => intensities[key] ?? 0.0;

  Paint _musclePaint(String key) {
    final intensity = _i(key);
    final color = _intensityToColor(intensity, glowPhase);
    final blur = _blurRadius(intensity);
    final p = Paint()..color = color;
    if (blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    return p;
  }

  Paint get _skin => Paint()..color = _baseSkin;

  Paint get _outline => Paint()
    ..color = Colors.white.withOpacity(0.15)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  /// ポンプスケール変換: 筋肉ゾーンを intensity に応じて若干膨張させる
  Path _scaled(Path path, double intensity, Offset center, Size size) {
    if (intensity < 0.1) return path;
    final s = _pumpScale(intensity);
    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(s, s)
      ..translate(-center.dx, -center.dy);
    return path.transform(matrix.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawBodyBase(canvas, w, h);

    if (showFront) {
      _drawFront(canvas, w, h);
    } else {
      _drawBack(canvas, w, h);
    }
  }

  void _drawBodyBase(Canvas canvas, double w, double h) {
    // 頭
    final headC = Offset(w / 2, h * 0.068);
    final headR = w * 0.11;
    canvas.drawCircle(headC, headR, _skin);
    canvas.drawCircle(headC, headR, _outline);

    // 首
    final neckPath = Path()
      ..moveTo(w * 0.44, h * 0.12)
      ..lineTo(w * 0.44, h * 0.155)
      ..lineTo(w * 0.56, h * 0.155)
      ..lineTo(w * 0.56, h * 0.12)
      ..close();
    canvas.drawPath(neckPath, _skin);
  }

  void _drawFront(Canvas canvas, double w, double h) {
    // ─── 胸 (大胸筋) ─── 左右の膨らんだ扇形
    final chestI = _i('chest');
    _drawMuscle(canvas, w, h, 'chest', () {
      final p = Path();
      // 左胸
      p.moveTo(w * 0.36, h * 0.155);
      p.cubicTo(w * 0.18, h * 0.17, w * 0.16, h * 0.24, w * 0.22, h * 0.31);
      p.cubicTo(w * 0.28, h * 0.34, w * 0.42, h * 0.34, w * 0.48, h * 0.30);
      p.lineTo(w * 0.48, h * 0.155);
      p.close();
      // 右胸
      p.moveTo(w * 0.64, h * 0.155);
      p.cubicTo(w * 0.82, h * 0.17, w * 0.84, h * 0.24, w * 0.78, h * 0.31);
      p.cubicTo(w * 0.72, h * 0.34, w * 0.58, h * 0.34, w * 0.52, h * 0.30);
      p.lineTo(w * 0.52, h * 0.155);
      p.close();
      return p;
    }, Offset(w * 0.5, h * 0.245));

    // ─── 肩 (三角筋前部) ───
    _drawMuscle(canvas, w, h, 'shoulders', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.32);
        p.addOval(Rect.fromCenter(
          center: Offset(cx, h * 0.185),
          width: w * 0.16,
          height: h * 0.10,
        ));
      }
      return p;
    }, Offset(w * 0.5, h * 0.185));

    // ─── 体幹/腹 (腹直筋) ─── 縦長の6パック風
    _drawMuscle(canvas, w, h, 'core', () {
      final p = Path();
      // 外側シルエット
      p.moveTo(w * 0.30, h * 0.31);
      p.cubicTo(w * 0.26, h * 0.36, w * 0.26, h * 0.44, w * 0.30, h * 0.48);
      p.cubicTo(w * 0.36, h * 0.50, w * 0.64, h * 0.50, w * 0.70, h * 0.48);
      p.cubicTo(w * 0.74, h * 0.44, w * 0.74, h * 0.36, w * 0.70, h * 0.31);
      p.close();
      return p;
    }, Offset(w * 0.5, h * 0.405));

    // ─── 二頭筋 ───
    _drawMuscle(canvas, w, h, 'biceps', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.36);
        p.addOval(Rect.fromCenter(
          center: Offset(cx, h * 0.33),
          width: w * 0.11,
          height: h * 0.14,
        ));
      }
      return p;
    }, Offset(w * 0.5, h * 0.33));

    // ─── 前腕 (腕橈骨筋) ─── ベースカラーのみ
    final forearmPath = Path();
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.36);
      forearmPath.addOval(Rect.fromCenter(
        center: Offset(cx, h * 0.46),
        width: w * 0.10,
        height: h * 0.11,
      ));
    }
    canvas.drawPath(forearmPath, _skin);
    canvas.drawPath(forearmPath, _outline);

    // ─── 大腿四頭筋 ───
    _drawMuscle(canvas, w, h, 'quads', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.135);
        p.moveTo(cx - w * 0.09, h * 0.50);
        p.cubicTo(cx - w * 0.11, h * 0.58, cx - w * 0.10, h * 0.67, cx - w * 0.08, h * 0.72);
        p.cubicTo(cx, h * 0.74, cx + w * 0.08, h * 0.72, cx + w * 0.08, h * 0.72);
        p.cubicTo(cx + w * 0.10, h * 0.67, cx + w * 0.11, h * 0.58, cx + w * 0.09, h * 0.50);
        p.close();
      }
      return p;
    }, Offset(w * 0.5, h * 0.61));

    // ─── ふくらはぎ (前面) ───
    _drawMuscle(canvas, w, h, 'calves', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.135);
        p.addOval(Rect.fromCenter(
          center: Offset(cx, h * 0.82),
          width: w * 0.13,
          height: h * 0.14,
        ));
      }
      return p;
    }, Offset(w * 0.5, h * 0.82));
  }

  void _drawBack(Canvas canvas, double w, double h) {
    // ─── 広背筋 (背中) ─── V字の大きな翼
    _drawMuscle(canvas, w, h, 'back', () {
      final p = Path();
      // 左広背筋
      p.moveTo(w * 0.50, h * 0.155);
      p.cubicTo(w * 0.50, h * 0.22, w * 0.30, h * 0.26, w * 0.18, h * 0.24);
      p.cubicTo(w * 0.14, h * 0.28, w * 0.18, h * 0.36, w * 0.26, h * 0.42);
      p.cubicTo(w * 0.34, h * 0.46, w * 0.46, h * 0.46, w * 0.50, h * 0.44);
      p.close();
      // 右広背筋
      p.moveTo(w * 0.50, h * 0.155);
      p.cubicTo(w * 0.50, h * 0.22, w * 0.70, h * 0.26, w * 0.82, h * 0.24);
      p.cubicTo(w * 0.86, h * 0.28, w * 0.82, h * 0.36, w * 0.74, h * 0.42);
      p.cubicTo(w * 0.66, h * 0.46, w * 0.54, h * 0.46, w * 0.50, h * 0.44);
      p.close();
      return p;
    }, Offset(w * 0.5, h * 0.31));

    // ─── 肩 (三角筋後部) ───
    _drawMuscle(canvas, w, h, 'shoulders', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.32);
        p.addOval(Rect.fromCenter(
          center: Offset(cx, h * 0.185),
          width: w * 0.16,
          height: h * 0.10,
        ));
      }
      return p;
    }, Offset(w * 0.5, h * 0.185));

    // ─── 三頭筋 ───
    _drawMuscle(canvas, w, h, 'triceps', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.36);
        p.addOval(Rect.fromCenter(
          center: Offset(cx, h * 0.33),
          width: w * 0.11,
          height: h * 0.14,
        ));
      }
      return p;
    }, Offset(w * 0.5, h * 0.33));

    // ─── 臀部 (大臀筋) ─── 丸みのある台形
    _drawMuscle(canvas, w, h, 'glutes', () {
      final p = Path();
      p.moveTo(w * 0.22, h * 0.44);
      p.cubicTo(w * 0.18, h * 0.48, w * 0.20, h * 0.56, w * 0.30, h * 0.58);
      p.cubicTo(w * 0.40, h * 0.60, w * 0.60, h * 0.60, w * 0.70, h * 0.58);
      p.cubicTo(w * 0.80, h * 0.56, w * 0.82, h * 0.48, w * 0.78, h * 0.44);
      p.close();
      return p;
    }, Offset(w * 0.5, h * 0.51));

    // ─── ハムストリング ───
    _drawMuscle(canvas, w, h, 'hamstrings', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.135);
        p.moveTo(cx - w * 0.09, h * 0.59);
        p.cubicTo(cx - w * 0.10, h * 0.66, cx - w * 0.09, h * 0.71, cx - w * 0.07, h * 0.73);
        p.cubicTo(cx + w * 0.07, h * 0.73, cx + w * 0.09, h * 0.71, cx + w * 0.10, h * 0.66);
        p.cubicTo(cx + w * 0.09, h * 0.59, cx + w * 0.09, h * 0.59, cx - w * 0.09, h * 0.59);
        p.close();
      }
      return p;
    }, Offset(w * 0.5, h * 0.66));

    // ─── ふくらはぎ (後面) ───
    _drawMuscle(canvas, w, h, 'calves', () {
      final p = Path();
      for (final xDir in [-1.0, 1.0]) {
        final cx = w * (0.5 + xDir * 0.135);
        // 腓腹筋の二頭構造を表現
        p.addOval(Rect.fromCenter(
          center: Offset(cx - w * 0.03, h * 0.80),
          width: w * 0.08,
          height: h * 0.12,
        ));
        p.addOval(Rect.fromCenter(
          center: Offset(cx + w * 0.03, h * 0.80),
          width: w * 0.08,
          height: h * 0.12,
        ));
      }
      return p;
    }, Offset(w * 0.5, h * 0.80));
  }

  /// 筋肉パスを描画する共通メソッド
  void _drawMuscle(
    Canvas canvas,
    double w,
    double h,
    String muscleKey,
    Path Function() buildPath,
    Offset center,
  ) {
    final intensity = _i(muscleKey);
    Path path = buildPath();

    // 強度に応じてパスを膨張
    if (intensity > 0.1) {
      path = _scaled(path, intensity, center, Size(w, h));
    }

    canvas.drawPath(path, _musclePaint(muscleKey));
    canvas.drawPath(path, _outline);
  }

  @override
  bool shouldRepaint(_AnatomicalBodyPainter old) =>
      old.glowPhase != glowPhase ||
      old.intensities != intensities ||
      old.showFront != showFront;
}
