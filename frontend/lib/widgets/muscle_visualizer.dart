// 筋肉部位ビジュアライザー v5 — 熊マスコット画像オーバーレイ版
// ─────────────────────────────────────────────────────────────────────────────
// v5 変更点:
//   - 自作の CustomPaint を撤廃し、ホーム画面と同じテイストの熊イラスト
//     (assets/ui/visualizer/bear_front_clean_20260505.png /
//      bear_back_clean_20260505.png) をベースにする
//   - 訓練済みの筋肉 (level >= 1) → オレンジのソフトオーバーレイで強調
//   - 未訓練の筋肉 (level 0) → 何も描かず、熊イラストをそのまま見せる
//   - 前面 / 背面それぞれに存在する部位だけを描画する
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

// ─────────────────────────────────────────────────────────────────────────────
// Muscle alias map
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<String>> _muscleAliases = {
  'chest': ['chest'],
  'back': ['back'],
  'shoulders': ['shoulders'],
  'biceps': ['biceps'],
  'triceps': ['triceps'],
  'legs': ['quads', 'hamstrings'],
  'quads': ['quads'],
  'hamstrings': ['hamstrings'],
  'glutes': ['glutes'],
  'calves': ['calves'],
  'core': ['core'],
  'traps': ['traps'],
  'full_body': [
    'chest',
    'back',
    'traps',
    'shoulders',
    'biceps',
    'triceps',
    'quads',
    'hamstrings',
    'glutes',
    'core'
  ],
};

const Map<String, String> _muscleJpNames = {
  'chest': '胸',
  'back': '広背筋',
  'traps': '僧帽筋',
  'shoulders': '肩',
  'biceps': '上腕二頭',
  'triceps': '上腕三頭',
  'quads': '大腿四頭',
  'hamstrings': 'ハムスト',
  'glutes': '臀筋',
  'calves': '下腿',
  'core': '腹',
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
  final double angle;
  const _Hotspot(this.cx, this.cy, this.w, this.h, [this.angle = 0.0]);
}

// 実際に保存されたイラストの自然サイズ。
// _MuscleOverlayPainter で BoxFit.contain の実描画領域を計算するために使う。
const Size _frontImageSize = Size(1024, 1536);
const Size _backImageSize = Size(1023, 1537);

// 前面の熊画像 (1024×1536) における各筋肉の位置 (正規化 0-1)。
// クリーンな白熊イラストに対して解剖学的に対応する位置を指定。
const Map<String, List<_Hotspot>> _frontHotspots = {
  // 胸 (タンクトップ上部の左右の大胸筋)
  'chest': [
    _Hotspot(0.455, 0.405, 0.085, 0.036),
    _Hotspot(0.595, 0.405, 0.085, 0.036),
  ],
  // 肩 (左右の三角筋)
  'shoulders': [
    _Hotspot(0.335, 0.395, 0.065, 0.044),
    _Hotspot(0.730, 0.395, 0.065, 0.044),
  ],
  // 上腕二頭筋 (前面の両上腕)
  'biceps': [
    _Hotspot(0.305, 0.485, 0.055, 0.076),
    _Hotspot(0.745, 0.485, 0.055, 0.076),
  ],
  // 腹直筋 (タンクトップ下部・M ロゴの右下に位置)
  'core': [_Hotspot(0.685, 0.535, 0.11, 0.048)],
  // 大腿四頭筋 (両太もも前面)
  'quads': [
    _Hotspot(0.440, 0.665, 0.145, 0.074, -0.16),
    _Hotspot(0.620, 0.665, 0.145, 0.074, 0.16),
  ],
  // ふくらはぎ (両下腿)
  'calves': [
    _Hotspot(0.430, 0.705, 0.115, 0.044, -0.18),
    _Hotspot(0.620, 0.705, 0.115, 0.044, 0.18),
  ],
};

// 背面の熊画像 (1023×1537) における各筋肉の位置 (正規化 0-1)。
const Map<String, List<_Hotspot>> _backHotspots = {
  // 僧帽筋 (タンクトップ上部・左右に分割)
  'traps': [
    _Hotspot(0.430, 0.410, 0.070, 0.028),
    _Hotspot(0.570, 0.410, 0.070, 0.028),
  ],
  // 広背筋 (タンク中央の左右に拡がる V 字)
  'back': [
    _Hotspot(0.420, 0.490, 0.075, 0.080),
    _Hotspot(0.580, 0.490, 0.075, 0.080),
  ],
  // 肩 (左右の三角筋後部)
  'shoulders': [
    _Hotspot(0.330, 0.425, 0.065, 0.044),
    _Hotspot(0.710, 0.425, 0.065, 0.044),
  ],
  // 上腕三頭筋 (背面の両上腕)
  'triceps': [
    _Hotspot(0.290, 0.545, 0.055, 0.084),
    _Hotspot(0.710, 0.545, 0.055, 0.084),
  ],
  // 臀筋 (ショーツに隠れている部位として控えめに)
  'glutes': [
    _Hotspot(0.445, 0.665, 0.060, 0.028),
    _Hotspot(0.565, 0.665, 0.060, 0.028),
  ],
  // ハムストリング (両太もも裏)
  'hamstrings': [
    _Hotspot(0.410, 0.765, 0.095, 0.060),
    _Hotspot(0.590, 0.765, 0.095, 0.060),
  ],
  // ふくらはぎ (両下腿)
  'calves': [
    _Hotspot(0.400, 0.845, 0.070, 0.050),
    _Hotspot(0.600, 0.845, 0.070, 0.050),
  ],
};

Set<String> _visibleMuscleKeys(bool showFront) =>
    showFront ? _frontHotspots.keys.toSet() : _backHotspots.keys.toSet();

// ─────────────────────────────────────────────────────────────────────────────
// MuscleVisualizer
// ─────────────────────────────────────────────────────────────────────────────
class MuscleVisualizer extends StatefulWidget {
  final List<String> trainedMuscles;
  final Map<String, double>? intensityMap;
  final String? contextLabel;

  const MuscleVisualizer({
    super.key,
    required this.trainedMuscles,
    this.intensityMap,
    this.contextLabel,
  });

  @override
  State<MuscleVisualizer> createState() => _MuscleVisualizerState();
}

class _MuscleVisualizerState extends State<MuscleVisualizer> {
  bool _showFront = true;

  Map<String, double> get _effectiveIntensity {
    final trained = _focusedMusclesForDisplay(
      widget.trainedMuscles,
      widget.contextLabel,
    );
    if (widget.intensityMap != null) {
      return {
        for (final entry in widget.intensityMap!.entries)
          entry.key: trained.contains(entry.key) ? entry.value : 0.0,
      };
    }
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
                            ? 'assets/ui/visualizer/bear_front_clean_20260505.png'
                            : 'assets/ui/visualizer/bear_back_clean_20260505.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _BearImageMissing(),
                      ),
                    ),
                    // ── オーバーレイ: 訓練済み部位だけを面別にハイライト ──
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

Set<String> _focusedMusclesForDisplay(
  List<String> muscles,
  String? contextLabel,
) {
  final trained = _resolve(muscles);
  final label = contextLabel?.toLowerCase() ?? '';
  if (label.isEmpty) return trained;

  if (_hasAny(label, const ['全身', 'full body', 'full_body'])) {
    return trained;
  }
  if (trained.contains('chest') &&
      _hasAny(label, const ['胸', 'chest', 'bench', 'ベンチ'])) {
    return {'chest'};
  }
  if (trained.contains('back') &&
      _hasAny(label, const ['背中', '広背', 'back', 'row', 'pull', 'ロウ'])) {
    return {'back'};
  }
  if (trained.contains('shoulders') &&
      _hasAny(label, const ['肩', 'shoulder', 'press', 'プレス'])) {
    return {'shoulders'};
  }
  if (trained.contains('biceps') &&
      _hasAny(label, const ['二頭', 'biceps', 'curl', 'カール'])) {
    return {'biceps'};
  }
  if (trained.contains('triceps') && _hasAny(label, const ['三頭', 'triceps'])) {
    return {'triceps'};
  }
  if (_hasAny(label, const ['脚', '足', 'leg', 'legs', 'lower'])) {
    final legMuscles =
        trained.intersection({'quads', 'hamstrings', 'glutes', 'calves'});
    if (legMuscles.isNotEmpty) return legMuscles;
  }
  if (trained.contains('core') &&
      _hasAny(label, const ['腹', '体幹', 'core', 'abs'])) {
    return {'core'};
  }
  return trained;
}

bool _hasAny(String text, List<String> needles) =>
    needles.any((needle) => text.contains(needle.toLowerCase()));

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
          '熊イラスト未配置\n\nassets/ui/visualizer/\n  bear_front_clean_20260505.png\n  bear_back_clean_20260505.png',
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
//   - 未訓練 (level 0): 何も描かない
//   - 訓練済み (level 1-3): 強度に応じたオレンジのソフトオーバル
//   - showFront に応じて前面 / 背面のホットスポットだけを使う
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

    // 訓練済みの筋肉だけをオレンジで強調する。
    // 未訓練の部位には何も描かない (イラストをそのまま見せる)。
    const highlightBase = Color(0xFFFF8A1C);
    final hotspots = showFront ? _frontHotspots : _backHotspots;
    for (final entry in hotspots.entries) {
      final key = entry.key;
      final level = _toLevel(intensities[key] ?? 0.0);
      if (level == 0) continue; // 鍛えていない部位は無加工

      // 強度に応じてオレンジの濃さと光のサイズを変える。
      // ホットスポット自体を画像のオーバルに合わせて細めにしているため、
      // inflate は最小限に抑えて滲みを抑制する。
      final alpha = level == 1
          ? 0.65
          : level == 2
              ? 0.85
              : 1.00;
      final blur = level == 3 ? 5.0 : 3.5;
      final inflate = level == 3 ? 1.5 : 0.0;

      for (final hs in entry.value) {
        final center = Offset(
          offsetX + hs.cx * renderedW,
          offsetY + hs.cy * renderedH,
        );
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: hs.w * renderedW,
          height: hs.h * renderedH,
        );
        final paint = Paint()
          ..color = highlightBase.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
        canvas
          ..save()
          ..translate(center.dx, center.dy)
          ..rotate(hs.angle)
          ..drawOval(rect.inflate(inflate), paint)
          ..restore();
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
    'chest',
    'back',
    'quads',
    'hamstrings',
    'glutes',
    'shoulders',
    'core',
    'traps',
    'biceps',
    'triceps',
    'calves',
  ];

  @override
  Widget build(BuildContext context) {
    final activated = intensities.entries
        .where((e) =>
            _visibleMuscleKeys(showFront).contains(e.key) &&
            _toLevel(e.value) > 0)
        .toList()
      ..sort((a, b) {
        final v = b.value.compareTo(a.value);
        if (v != 0) return v;
        final ai = _priorityOrder.indexOf(a.key);
        final bi = _priorityOrder.indexOf(b.key);
        return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
      });

    final primaryKey = _priorityOrder.firstWhere(
      (k) =>
          _visibleMuscleKeys(showFront).contains(k) &&
          _toLevel(intensities[k] ?? 0.0) > 0,
      orElse: () => '',
    );
    final primaryName =
        primaryKey.isEmpty ? '—' : (_muscleJpNames[primaryKey] ?? primaryKey);
    final activatedNames =
        activated.map((e) => _muscleJpNames[e.key] ?? e.key).join('・');
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '部位',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      activatedNames.isEmpty ? '—' : activatedNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
