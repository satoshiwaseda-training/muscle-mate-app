// 筋肉部位ビジュアライザー v3 — Analysis Panel
// ─────────────────────────────────────────────────────────────────────────────
// v3 変更点:
//   - グロー/パルスアニメーション廃止 → 静的分析UIに
//   - 4段階強度 (0-3) の明度差のみで表現（level3のみblurRadius:1.5）
//   - 僧帽筋 (traps) を背面ビューに追加
//   - 左: 人体図 / 右: 分析サイドバー の2カラムレイアウト
//   - BIG3プログレスバー廃止
//   - ボトム凡例廃止（サイドバーに統合）
//   - SVGスタイル: 名前付きパス + fill-only + 最小ストローク
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

// ─────────────────────────────────────────────────────────────────────────────
// Muscle alias map
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<String>> _muscleAliases = {
  'chest':      ['chest'],
  'back':       ['back', 'traps'], // 広背筋 + 僧帽筋
  'shoulders':  ['shoulders'],
  'biceps':     ['biceps'],
  'triceps':    ['triceps'],
  'legs':       ['quads', 'hamstrings'],
  'quads':      ['quads'],
  'hamstrings': ['hamstrings'],
  'glutes':     ['glutes'],
  'calves':     ['calves'],
  'core':       ['core'],
  'traps':      ['traps'],
  'full_body':  ['chest','back','traps','shoulders','biceps','triceps',
                 'quads','hamstrings','glutes','core'],
};

const Map<String, String> _muscleJpNames = {
  'chest':      '胸',
  'back':       '広背筋',
  'traps':      '僧帽筋',
  'shoulders':  '肩',
  'biceps':     '上腕二頭',
  'triceps':    '上腕三頭',
  'quads':      '大腿四頭',
  'hamstrings': 'ハムスト',
  'glutes':     '臀筋',
  'calves':     '下腿',
  'core':       '腹',
};

Set<String> _resolve(List<String> muscles) {
  final result = <String>{};
  for (final m in muscles) {
    result.addAll(_muscleAliases[m] ?? [m]);
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Intensity helpers (0–3 levels)
// ─────────────────────────────────────────────────────────────────────────────

int _toLevel(double intensity) {
  if (intensity <= 0.0) return 0;
  if (intensity < 0.34) return 1;
  if (intensity < 0.67) return 2;
  return 3;
}

/// 4段階 → 色 (orangeのみ使用、白発光なし)
Color _levelToColor(int level) {
  switch (level) {
    case 1: return AppColors.primary.withValues(alpha: 0.28);
    case 2: return AppColors.primary.withValues(alpha: 0.62);
    case 3: return AppColors.primary;
    default: return const Color(0xFF1C1C20); // surfaceHigh
  }
}

/// level 3 のみ極薄グロー
double _levelGlow(int level) => level == 3 ? 1.5 : 0.0;

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class MuscleVisualizer extends StatefulWidget {
  final List<String> trainedMuscles;

  /// /visualizer/heatmap から取得した 0.0〜1.0 強度マップ（任意）
  final Map<String, double>? intensityMap;

  const MuscleVisualizer({
    super.key,
    required this.trainedMuscles,
    this.intensityMap,
  });

  @override
  State<MuscleVisualizer> createState() => _MuscleVisualizerState();
}

class _MuscleVisualizerState extends State<MuscleVisualizer> {
  bool _showFront = true;

  Map<String, double> get _effectiveIntensity {
    if (widget.intensityMap != null) return widget.intensityMap!;
    final trained = _resolve(widget.trainedMuscles);
    return {
      for (final key in _muscleJpNames.keys)
        key: trained.contains(key) ? 1.0 : 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final intensities = _effectiveIntensity;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 人体図 ──────────────────────────────────────────────────────────
        SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildViewToggle(),
              const SizedBox(height: AppColors.gapS),
              SizedBox(
                width: 160,
                height: 267, // 160 × (370/220)
                child: CustomPaint(
                  painter: _BodyPainter(
                    intensities: intensities,
                    showFront: _showFront,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppColors.gapXL + AppColors.gapS / 2),
        // ── 分析サイドバー ──────────────────────────────────────────────────
        Expanded(
          child: _AnalysisPanel(
            intensities: intensities,
            showFront: _showFront,
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppColors.radiusS),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillBtn('前面', true),
          _pillBtn('背面', false),
        ],
      ),
    );
  }

  Widget _pillBtn(String label, bool front) {
    final active = _showFront == front;
    return GestureDetector(
      onTap: () => setState(() => _showFront = front),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppColors.radiusS - 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecond,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analysis Panel
// ─────────────────────────────────────────────────────────────────────────────

class _AnalysisPanel extends StatelessWidget {
  final Map<String, double> intensities;
  final bool showFront;

  const _AnalysisPanel({
    required this.intensities,
    required this.showFront,
  });

  // 大筋群優先の表示順（重点部位の選択に使用）
  static const _priorityOrder = [
    'chest', 'back', 'quads', 'hamstrings', 'glutes',
    'shoulders', 'core', 'traps', 'biceps', 'triceps', 'calves',
  ];

  @override
  Widget build(BuildContext context) {
    // 活性化部位: intensity降順 → 同値は優先順でソート
    final activated = intensities.entries
        .where((e) => _toLevel(e.value) > 0)
        .toList()
      ..sort((a, b) {
        final v = b.value.compareTo(a.value);
        if (v != 0) return v;
        final ai = _priorityOrder.indexOf(a.key);
        final bi = _priorityOrder.indexOf(b.key);
        return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
      });

    // 重点部位: 大筋群優先で最初に見つかった活性化部位
    final primaryKey = _priorityOrder.firstWhere(
      (k) => _toLevel(intensities[k] ?? 0.0) > 0,
      orElse: () => '',
    );
    final primaryName = primaryKey.isEmpty
        ? '—'
        : (_muscleJpNames[primaryKey] ?? primaryKey);
    final restHint = primaryKey.isEmpty
        ? '記録が増えると、次に休ませたい部位が見えてきます。'
        : '次回は$primaryNameを休ませるか、軽めにすると続けやすくなります。';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showFront ? '前面の使った部位' : '背面の使った部位',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '今日はここを使いました。色が濃いほど刺激が大きい目安です。',
          style: TextStyle(
            color: AppColors.textSecond,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppColors.gapL),
        // ── 要約: 重点部位 ──────────────────────────────────────────
        _micro('よく使った部位'),
        const SizedBox(height: 4),
        Text(
          primaryName,
          style: TextStyle(
            color: primaryKey.isEmpty
                ? Colors.white.withValues(alpha: 0.34)
                : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
        const SizedBox(height: AppColors.gapL),
        // ── 数: 刺激部位数 ──────────────────────────────────────────
        _micro('刺激部位'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${activated.length}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                '部位',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        // ── 詳細: 高刺激部位 ────────────────────────────────────────
        if (activated.isNotEmpty) ...[
          const SizedBox(height: AppColors.gapL),
          _micro('刺激が大きい部位'),
          const SizedBox(height: AppColors.gapS),
          ...activated.take(4).map(
            (e) => _MuscleRow(
              name: _muscleJpNames[e.key] ?? e.key,
              level: _toLevel(e.value),
            ),
          ),
        ],
        const SizedBox(height: AppColors.gapM),
        Text(
          restHint,
          style: const TextStyle(
            color: AppColors.textSecond,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _micro(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );
}

class _MuscleRow extends StatelessWidget {
  final String name;
  final int level;

  const _MuscleRow({required this.name, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _levelToColor(level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body Painter — SVGスタイル (named paths, fill + minimal stroke)
// ─────────────────────────────────────────────────────────────────────────────

class _BodyPainter extends CustomPainter {
  final Map<String, double> intensities;
  final bool showFront;

  const _BodyPainter({required this.intensities, required this.showFront});

  static const _baseSkin = Color(0xFF2A2A2E);

  int _level(String key) => _toLevel(intensities[key] ?? 0.0);

  Paint _fill(String key) {
    final level = _level(key);
    final color = _levelToColor(level);
    final p = Paint()..color = color;
    final glow = _levelGlow(level);
    if (glow > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, glow);
    return p;
  }

  Paint get _skin => Paint()..color = _baseSkin;

  Paint get _stroke => Paint()
    ..color = Colors.white.withValues(alpha: 0.10)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;

  // 名前付きパスを fill + stroke で描画
  void _draw(Canvas canvas, String key, Path path) {
    canvas.drawPath(path, _fill(key));
    canvas.drawPath(path, _stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawBase(canvas, w, h);
    if (showFront) {
      _drawFront(canvas, w, h);
    } else {
      _drawBack(canvas, w, h);
    }
  }

  void _drawBase(Canvas canvas, double w, double h) {
    canvas.drawCircle(Offset(w / 2, h * 0.068), w * 0.11, _skin);
    canvas.drawCircle(Offset(w / 2, h * 0.068), w * 0.11, _stroke);
    final neck = Path()
      ..moveTo(w * 0.44, h * 0.12)
      ..lineTo(w * 0.44, h * 0.155)
      ..lineTo(w * 0.56, h * 0.155)
      ..lineTo(w * 0.56, h * 0.12)
      ..close();
    canvas.drawPath(neck, _skin);
  }

  void _drawFront(Canvas canvas, double w, double h) {
    // 胸 (大胸筋)
    _draw(canvas, 'chest', Path()
      ..moveTo(w * 0.36, h * 0.155)
      ..cubicTo(w * 0.18, h * 0.17, w * 0.16, h * 0.24, w * 0.22, h * 0.31)
      ..cubicTo(w * 0.28, h * 0.34, w * 0.42, h * 0.34, w * 0.48, h * 0.30)
      ..lineTo(w * 0.48, h * 0.155)
      ..close()
      ..moveTo(w * 0.64, h * 0.155)
      ..cubicTo(w * 0.82, h * 0.17, w * 0.84, h * 0.24, w * 0.78, h * 0.31)
      ..cubicTo(w * 0.72, h * 0.34, w * 0.58, h * 0.34, w * 0.52, h * 0.30)
      ..lineTo(w * 0.52, h * 0.155)
      ..close());

    // 肩 (三角筋前部)
    _draw(canvas, 'shoulders', Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.18, h * 0.185), width: w * 0.16, height: h * 0.10))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.82, h * 0.185), width: w * 0.16, height: h * 0.10)));

    // 腹 (腹直筋)
    _draw(canvas, 'core', Path()
      ..moveTo(w * 0.30, h * 0.31)
      ..cubicTo(w * 0.26, h * 0.36, w * 0.26, h * 0.44, w * 0.30, h * 0.48)
      ..cubicTo(w * 0.36, h * 0.50, w * 0.64, h * 0.50, w * 0.70, h * 0.48)
      ..cubicTo(w * 0.74, h * 0.44, w * 0.74, h * 0.36, w * 0.70, h * 0.31)
      ..close());

    // 上腕二頭筋
    _draw(canvas, 'biceps', Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.14, h * 0.33), width: w * 0.11, height: h * 0.14))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.86, h * 0.33), width: w * 0.11, height: h * 0.14)));

    // 前腕 (ニュートラル固定)
    final forearm = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.14, h * 0.46), width: w * 0.10, height: h * 0.11))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.86, h * 0.46), width: w * 0.10, height: h * 0.11));
    canvas.drawPath(forearm, _skin);
    canvas.drawPath(forearm, _stroke);

    // 大腿四頭筋
    final quads = Path();
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.135);
      quads
        ..moveTo(cx - w * 0.09, h * 0.50)
        ..cubicTo(cx - w * 0.11, h * 0.58, cx - w * 0.10, h * 0.67,
            cx - w * 0.08, h * 0.72)
        ..cubicTo(cx, h * 0.74, cx + w * 0.08, h * 0.72, cx + w * 0.08, h * 0.72)
        ..cubicTo(cx + w * 0.10, h * 0.67, cx + w * 0.11, h * 0.58,
            cx + w * 0.09, h * 0.50)
        ..close();
    }
    _draw(canvas, 'quads', quads);

    // 下腿 (前脛骨筋)
    _draw(canvas, 'calves', Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.365, h * 0.82), width: w * 0.13, height: h * 0.14))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.635, h * 0.82), width: w * 0.13, height: h * 0.14)));
  }

  void _drawBack(Canvas canvas, double w, double h) {
    // 僧帽筋 (上部菱形)
    _draw(canvas, 'traps', Path()
      ..moveTo(w * 0.50, h * 0.155)
      ..cubicTo(w * 0.38, h * 0.155, w * 0.24, h * 0.16, w * 0.18, h * 0.20)
      ..cubicTo(w * 0.22, h * 0.24, w * 0.34, h * 0.245, w * 0.50, h * 0.225)
      ..cubicTo(w * 0.66, h * 0.245, w * 0.78, h * 0.24, w * 0.82, h * 0.20)
      ..cubicTo(w * 0.76, h * 0.16, w * 0.62, h * 0.155, w * 0.50, h * 0.155)
      ..close());

    // 広背筋 (V字翼)
    _draw(canvas, 'back', Path()
      ..moveTo(w * 0.50, h * 0.225)
      ..cubicTo(w * 0.50, h * 0.27, w * 0.30, h * 0.29, w * 0.18, h * 0.27)
      ..cubicTo(w * 0.14, h * 0.31, w * 0.18, h * 0.39, w * 0.26, h * 0.45)
      ..cubicTo(w * 0.34, h * 0.48, w * 0.46, h * 0.47, w * 0.50, h * 0.455)
      ..close()
      ..moveTo(w * 0.50, h * 0.225)
      ..cubicTo(w * 0.50, h * 0.27, w * 0.70, h * 0.29, w * 0.82, h * 0.27)
      ..cubicTo(w * 0.86, h * 0.31, w * 0.82, h * 0.39, w * 0.74, h * 0.45)
      ..cubicTo(w * 0.66, h * 0.48, w * 0.54, h * 0.47, w * 0.50, h * 0.455)
      ..close());

    // 肩 (三角筋後部)
    _draw(canvas, 'shoulders', Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.18, h * 0.185), width: w * 0.16, height: h * 0.10))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.82, h * 0.185), width: w * 0.16, height: h * 0.10)));

    // 上腕三頭筋
    _draw(canvas, 'triceps', Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.14, h * 0.33), width: w * 0.11, height: h * 0.14))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.86, h * 0.33), width: w * 0.11, height: h * 0.14)));

    // 臀筋
    _draw(canvas, 'glutes', Path()
      ..moveTo(w * 0.22, h * 0.455)
      ..cubicTo(w * 0.18, h * 0.49, w * 0.20, h * 0.57, w * 0.30, h * 0.59)
      ..cubicTo(w * 0.40, h * 0.61, w * 0.60, h * 0.61, w * 0.70, h * 0.59)
      ..cubicTo(w * 0.80, h * 0.57, w * 0.82, h * 0.49, w * 0.78, h * 0.455)
      ..close());

    // ハムストリング
    final hams = Path();
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.135);
      hams
        ..moveTo(cx - w * 0.09, h * 0.60)
        ..cubicTo(cx - w * 0.10, h * 0.67, cx - w * 0.09, h * 0.72,
            cx - w * 0.07, h * 0.74)
        ..cubicTo(cx + w * 0.07, h * 0.74, cx + w * 0.09, h * 0.72,
            cx + w * 0.10, h * 0.67)
        ..cubicTo(cx + w * 0.09, h * 0.60, cx + w * 0.09, h * 0.60,
            cx - w * 0.09, h * 0.60)
        ..close();
    }
    _draw(canvas, 'hamstrings', hams);

    // ふくらはぎ (腓腹筋二頭)
    final calves = Path();
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.135);
      calves
        ..addOval(Rect.fromCenter(
            center: Offset(cx - w * 0.03, h * 0.81),
            width: w * 0.08, height: h * 0.12))
        ..addOval(Rect.fromCenter(
            center: Offset(cx + w * 0.03, h * 0.81),
            width: w * 0.08, height: h * 0.12));
    }
    _draw(canvas, 'calves', calves);
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.intensities != intensities || old.showFront != showFront;
}
