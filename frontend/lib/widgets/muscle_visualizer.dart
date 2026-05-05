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

// ─────────────────────────────────────────────────────────────────────────────
// _BodyPainter (v4: マスコット熊風のチビキャラ)
//   ホーム画面の白熊マスコットに合わせた親しみやすいフォルム。
//   厳密な解剖学より「どこを使ったかが一目でわかる + かわいい」を優先。
//   マッスルグループのキー（chest/back/...）は維持しているので
//   intensityMap や Analysis Panel との互換性は保たれている。
// ─────────────────────────────────────────────────────────────────────────────
class _BodyPainter extends CustomPainter {
  final Map<String, double> intensities;
  final bool showFront;

  const _BodyPainter({required this.intensities, required this.showFront});

  // 熊の地肌（白っぽいアイボリー）
  static const _bearFur = Color(0xFFF5EFE3);
  // 熊の影色（耳の内側・口元など）
  static const _bearShadow = Color(0xFFD9CFB7);
  // 熊の目・鼻（温かみのある黒茶）
  static const _bearInk = Color(0xFF2B201A);

  int _level(String key) => _toLevel(intensities[key] ?? 0.0);

  Paint _fill(String key) {
    final level = _level(key);
    final color = _levelToColor(level);
    final p = Paint()..color = color;
    final glow = _levelGlow(level);
    if (glow > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, glow);
    return p;
  }

  Paint get _fur => Paint()..color = _bearFur;
  Paint get _shadow => Paint()..color = _bearShadow;
  Paint get _ink => Paint()..color = _bearInk;

  Paint get _stroke => Paint()
    ..color = _bearShadow.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  // 名前付きパスを fill + 細ストロークで描画
  void _drawMuscle(Canvas canvas, String key, Path path) {
    canvas.drawPath(path, _fill(key));
    canvas.drawPath(path, _stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawBody(canvas, w, h); // 地肌（手脚＋胴体）
    _drawHead(canvas, w, h); // 顔（耳・目鼻）
    if (showFront) {
      _drawFront(canvas, w, h);
    } else {
      _drawBack(canvas, w, h);
    }
  }

  // 胴体・手脚の地肌（マスコット白熊のシルエット）
  void _drawBody(Canvas canvas, double w, double h) {
    // 胴体 (チビ寸法・丸みのある四角)
    final torso = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.27, h * 0.30, w * 0.73, h * 0.60),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(torso, _fur);
    canvas.drawRRect(torso, _stroke);

    // 腕 (左右・短く太く・丸い)
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.34);
      final arm = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.41),
          width: w * 0.16,
          height: h * 0.24,
        ),
        Radius.circular(w * 0.07),
      );
      canvas.drawRRect(arm, _fur);
      canvas.drawRRect(arm, _stroke);
    }

    // 脚 (左右・短く太く・丸い)
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.16);
      final leg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.78),
          width: w * 0.20,
          height: h * 0.34,
        ),
        Radius.circular(w * 0.08),
      );
      canvas.drawRRect(leg, _fur);
      canvas.drawRRect(leg, _stroke);
    }
  }

  // 熊の顔（前面のときは目鼻、背面では後頭部のみ）
  void _drawHead(Canvas canvas, double w, double h) {
    final headCenter = Offset(w * 0.5, h * 0.13);
    final headRadius = w * 0.20;

    // 耳（左右・小さく丸く）
    for (final xDir in [-1.0, 1.0]) {
      final earCenter = Offset(
        w * (0.5 + xDir * 0.18),
        h * 0.04,
      );
      canvas.drawCircle(earCenter, w * 0.07, _fur);
      canvas.drawCircle(earCenter, w * 0.07, _stroke);
      // 耳の内側
      canvas.drawCircle(earCenter, w * 0.035, _shadow);
    }

    // 顔本体
    canvas.drawCircle(headCenter, headRadius, _fur);
    canvas.drawCircle(headCenter, headRadius, _stroke);

    if (showFront) {
      // 鼻まわり（口元の薄いアイボリー）
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.155),
          width: w * 0.20,
          height: h * 0.07,
        ),
        _shadow,
      );

      // 目（左右の黒丸・光沢小ドット付き）
      for (final xDir in [-1.0, 1.0]) {
        final eyeCenter = Offset(w * (0.5 + xDir * 0.085), h * 0.115);
        canvas.drawCircle(eyeCenter, w * 0.022, _ink);
        canvas.drawCircle(
          Offset(eyeCenter.dx + w * 0.008, eyeCenter.dy - h * 0.005),
          w * 0.008,
          Paint()..color = Colors.white,
        );
      }

      // 鼻
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.142),
          width: w * 0.038,
          height: h * 0.022,
        ),
        _ink,
      );

      // 口（小さな笑顔）
      final mouth = Path()
        ..moveTo(w * 0.46, h * 0.165)
        ..quadraticBezierTo(w * 0.5, h * 0.180, w * 0.54, h * 0.165);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = _bearInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    // 背面のときは何も描かない（後頭部の白い円のみ）
  }

  // ── 前面: 各部位を熊の体の上にカラー付きパッチで重ねる ──────────────
  void _drawFront(Canvas canvas, double w, double h) {
    // 胸 (横長の丸み・タンクトップ風の上部)
    _drawMuscle(
      canvas,
      'chest',
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.30, h * 0.31, w * 0.70, h * 0.43),
          Radius.circular(w * 0.05),
        )),
    );

    // 肩 (左右の小円・やわらかい)
    _drawMuscle(
      canvas,
      'shoulders',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.18, h * 0.32),
            width: w * 0.18,
            height: h * 0.10))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.82, h * 0.32),
            width: w * 0.18,
            height: h * 0.10)),
    );

    // 腹 (核心・お腹のまるい部分)
    _drawMuscle(
      canvas,
      'core',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.50),
            width: w * 0.32,
            height: h * 0.16)),
    );

    // 上腕二頭筋 (両腕の上半分に丸く)
    _drawMuscle(
      canvas,
      'biceps',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.16, h * 0.40),
            width: w * 0.13,
            height: h * 0.13))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.84, h * 0.40),
            width: w * 0.13,
            height: h * 0.13)),
    );

    // 大腿四頭筋 (両脚の上半分)
    final quads = Path();
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.16);
      quads.addOval(Rect.fromCenter(
        center: Offset(cx, h * 0.71),
        width: w * 0.16,
        height: h * 0.18,
      ));
    }
    _drawMuscle(canvas, 'quads', quads);

    // ふくらはぎ前面 (両脚の下半分)
    _drawMuscle(
      canvas,
      'calves',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.34, h * 0.88),
            width: w * 0.14,
            height: h * 0.12))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.66, h * 0.88),
            width: w * 0.14,
            height: h * 0.12)),
    );
  }

  // ── 背面: 後ろから見た熊。同じ胴体に背中側の部位を重ねる ─────────
  void _drawBack(Canvas canvas, double w, double h) {
    // 僧帽筋 (上背中央の丸い肩こり部分)
    _drawMuscle(
      canvas,
      'traps',
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.30, h * 0.30, w * 0.70, h * 0.38),
          Radius.circular(w * 0.05),
        )),
    );

    // 広背筋 (V字翼を控えめに・胴体に収まるサイズ)
    _drawMuscle(
      canvas,
      'back',
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.28, h * 0.38, w * 0.72, h * 0.55),
          Radius.circular(w * 0.06),
        )),
    );

    // 肩 (三角筋後部)
    _drawMuscle(
      canvas,
      'shoulders',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.18, h * 0.32),
            width: w * 0.18,
            height: h * 0.10))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.82, h * 0.32),
            width: w * 0.18,
            height: h * 0.10)),
    );

    // 上腕三頭筋 (両腕の上半分)
    _drawMuscle(
      canvas,
      'triceps',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.16, h * 0.40),
            width: w * 0.13,
            height: h * 0.13))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.84, h * 0.40),
            width: w * 0.13,
            height: h * 0.13)),
    );

    // 臀筋 (お尻の丸み)
    _drawMuscle(
      canvas,
      'glutes',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.36, h * 0.59),
            width: w * 0.18,
            height: h * 0.10))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.64, h * 0.59),
            width: w * 0.18,
            height: h * 0.10)),
    );

    // ハムストリング (両脚の上半分)
    final hams = Path();
    for (final xDir in [-1.0, 1.0]) {
      final cx = w * (0.5 + xDir * 0.16);
      hams.addOval(Rect.fromCenter(
        center: Offset(cx, h * 0.71),
        width: w * 0.16,
        height: h * 0.18,
      ));
    }
    _drawMuscle(canvas, 'hamstrings', hams);

    // ふくらはぎ (腓腹筋)
    _drawMuscle(
      canvas,
      'calves',
      Path()
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.34, h * 0.88),
            width: w * 0.14,
            height: h * 0.12))
        ..addOval(Rect.fromCenter(
            center: Offset(w * 0.66, h * 0.88),
            width: w * 0.14,
            height: h * 0.12)),
    );
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.intensities != intensities || old.showFront != showFront;
}
