// 筋肉部位ビジュアライザー v5 — 熊マスコット画像オーバーレイ版
// ─────────────────────────────────────────────────────────────────────────────
// v5 変更点:
//   - 自作の CustomPaint を撤廃し、ホーム画面と同じテイストの熊イラスト
//     (assets/ui/visualizer/bear_front.png / bear_back.png) をベースにする
//   - 訓練済みの筋肉 (level >= 1) → イラストの色が見える
//   - 未訓練の筋肉 (level 0) → そのホットスポットに暗いソフトオーバーレイを
//     被せて「今日は触れていない」と表現
//   - 高強度 (level 3) → 周囲にオレンジのグロー
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

// ─────────────────────────────────────────────────────────────────────────────
// Muscle alias map
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<String>> _muscleAliases = {
  'chest':      ['chest'],
  'back':       ['back', 'traps'],
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

int _toLevel(double intensity) {
  if (intensity <= 0.0) return 0;
  if (intensity < 0.34) return 1;
  if (intensity < 0.67) return 2;
  return 3;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hotspot 定義（0.0〜1.0 の正規化座標）
//   ユーザー提供の熊イラストにおける各筋肉の中心位置とサイズ。
//   オーバーレイ (暗化 / グロー) を描画する範囲を決める。
// ─────────────────────────────────────────────────────────────────────────────
class _Hotspot {
  /// 画像の自然座標系での 0.0〜1.0 正規化中心位置とサイズ
  final double cx;
  final double cy;
  final double w;
  final double h;
  const _Hotspot(this.cx, this.cy, this.w, this.h);
}

// 実際に保存されたイラストの自然サイズ。
// _MuscleOverlayPainter で BoxFit.contain の実描画領域を計算するために使う。
const Size _frontImageSize = Size(659, 1234);
const Size _backImageSize = Size(1122, 1402);

const Map<String, List<_Hotspot>> _frontHotspots = {
  'chest': [_Hotspot(0.50, 0.36, 0.42, 0.10)],
  'shoulders': [
    _Hotspot(0.20, 0.36, 0.13, 0.09),
    _Hotspot(0.80, 0.36, 0.13, 0.09),
  ],
  'biceps': [
    _Hotspot(0.13, 0.46, 0.12, 0.11),
    _Hotspot(0.87, 0.46, 0.12, 0.11),
  ],
  'core': [_Hotspot(0.50, 0.62, 0.28, 0.12)],
  'quads': [
    _Hotspot(0.36, 0.79, 0.13, 0.13),
    _Hotspot(0.64, 0.79, 0.13, 0.13),
  ],
  'calves': [
    _Hotspot(0.34, 0.92, 0.10, 0.07),
    _Hotspot(0.66, 0.92, 0.10, 0.07),
  ],
};

const Map<String, List<_Hotspot>> _backHotspots = {
  'traps': [_Hotspot(0.50, 0.40, 0.40, 0.06)],
  'back': [_Hotspot(0.50, 0.55, 0.34, 0.16)],
  'shoulders': [
    _Hotspot(0.20, 0.39, 0.13, 0.09),
    _Hotspot(0.80, 0.39, 0.13, 0.09),
  ],
  'triceps': [
    _Hotspot(0.13, 0.49, 0.12, 0.13),
    _Hotspot(0.87, 0.49, 0.12, 0.13),
  ],
  'glutes': [
    _Hotspot(0.40, 0.66, 0.10, 0.06),
    _Hotspot(0.60, 0.66, 0.10, 0.06),
  ],
  'hamstrings': [
    _Hotspot(0.36, 0.78, 0.13, 0.13),
    _Hotspot(0.64, 0.78, 0.13, 0.13),
  ],
  'calves': [
    _Hotspot(0.34, 0.92, 0.10, 0.07),
    _Hotspot(0.66, 0.92, 0.10, 0.07),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// MuscleVisualizer
// ─────────────────────────────────────────────────────────────────────────────
class MuscleVisualizer extends StatefulWidget {
  final List<String> trainedMuscles;
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
        SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildViewToggle(),
              const SizedBox(height: AppColors.gapS),
              SizedBox(
                width: 160,
                height: 267,
                child: Stack(
                  children: [
                    // ── ベース: 熊イラスト ─────────────────────
                    Positioned.fill(
                      child: Image.asset(
                        _showFront
                            ? 'assets/ui/visualizer/bear_front.png'
                            : 'assets/ui/visualizer/bear_back.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const _BearImageMissing(),
                      ),
                    ),
                    // ── オーバーレイ: 未訓練に暗化 + 訓練にグロー ──
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MuscleOverlayPainter(
                          intensities: intensities,
                          showFront: _showFront,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppColors.gapXL + AppColors.gapS / 2),
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
// _BearImageMissing
//   画像アセット未配置時のフォールバック表示
// ─────────────────────────────────────────────────────────────────────────────
class _BearImageMissing extends StatelessWidget {
  const _BearImageMissing();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: const Center(
        child: Text(
          '熊イラスト未配置\n\nassets/ui/visualizer/\n  bear_front.png\n  bear_back.png',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecond,
            fontSize: 10,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MuscleOverlayPainter
//   熊イラストの上に重ねるオーバーレイ。
//   - 未訓練 (level 0): 暗いソフトオーバル → 暗化
//   - 訓練済み (level 1-2): 何もしない (イラストの色が見える)
//   - 高強度 (level 3): 周囲にオレンジのグロー
// ─────────────────────────────────────────────────────────────────────────────
class _MuscleOverlayPainter extends CustomPainter {
  final Map<String, double> intensities;
  final bool showFront;

  const _MuscleOverlayPainter({
    required this.intensities,
    required this.showFront,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // BoxFit.contain で画像が実際に描画される領域を計算する。
    // ここで計算した rect 内でホットスポットを配置することで、
    // 異なるアスペクト比の画像でも筋肉位置がイラストとずれない。
    final imageSize = showFront ? _frontImageSize : _backImageSize;
    final imageAspect = imageSize.width / imageSize.height;
    final containerAspect = size.width / size.height;

    final double renderedW;
    final double renderedH;
    final double offsetX;
    final double offsetY;
    if (imageAspect < containerAspect) {
      // 画像の方が縦長 → 高さに合わせて描画
      renderedH = size.height;
      renderedW = size.height * imageAspect;
      offsetX = (size.width - renderedW) / 2;
      offsetY = 0;
    } else {
      // 画像の方が横長 → 幅に合わせて描画
      renderedW = size.width;
      renderedH = size.width / imageAspect;
      offsetX = 0;
      offsetY = (size.height - renderedH) / 2;
    }

    final hotspots = showFront ? _frontHotspots : _backHotspots;
    for (final entry in hotspots.entries) {
      final key = entry.key;
      final level = _toLevel(intensities[key] ?? 0.0);
      for (final hs in entry.value) {
        final rect = Rect.fromCenter(
          center: Offset(
            offsetX + hs.cx * renderedW,
            offsetY + hs.cy * renderedH,
          ),
          width: hs.w * renderedW,
          height: hs.h * renderedH,
        );
        if (level == 0) {
          // 未訓練: 暗いソフトオーバル
          final paint = Paint()
            ..color = const Color(0xFF101719).withValues(alpha: 0.65)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawOval(rect.inflate(2), paint);
        } else if (level >= 3) {
          // 高強度: 周囲にオレンジのグロー (イラストの色は維持)
          final glow = Paint()
            ..color = AppColors.primary.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawOval(rect.inflate(4), glow);
        }
        // level 1-2 はオーバーレイなし (イラストそのままで OK)
      }
    }
  }

  @override
  bool shouldRepaint(_MuscleOverlayPainter old) =>
      old.intensities != intensities || old.showFront != showFront;
}

// ─────────────────────────────────────────────────────────────────────────────
// Analysis Panel (右側のサイドバー・既存機能を維持)
// ─────────────────────────────────────────────────────────────────────────────
class _AnalysisPanel extends StatelessWidget {
  final Map<String, double> intensities;
  final bool showFront;

  const _AnalysisPanel({
    required this.intensities,
    required this.showFront,
  });

  static const _priorityOrder = [
    'chest', 'back', 'quads', 'hamstrings', 'glutes',
    'shoulders', 'core', 'traps', 'biceps', 'triceps', 'calves',
  ];

  @override
  Widget build(BuildContext context) {
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
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '部位',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppColors.gapL),
        _micro('参考メモ'),
        const SizedBox(height: 4),
        Text(
          restHint,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _micro(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Muscle row (compact list - retained for compatibility)
// ─────────────────────────────────────────────────────────────────────────────
class _MuscleRow extends StatelessWidget {
  final String label;
  final int level;
  // ignore: unused_element_parameter
  const _MuscleRow({required this.label, required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF1C1C20),
      AppColors.primary.withValues(alpha: 0.28),
      AppColors.primary.withValues(alpha: 0.62),
      AppColors.primary,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors[level.clamp(0, 3)],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
