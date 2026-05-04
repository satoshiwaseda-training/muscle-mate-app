// Advisory レベルに応じてモーダル/バナーを切り替える共通ウィジェット
// 計画書 v5 §6.4 §9.2 の Flutter 分岐仕様に対応
//
// - rest_or_consult: 休止モーダル（OK しないと進めない）
// - partial_skip: 警告バナー
// - deload: デロード提案ダイアログ（受諾/拒否を選択）
// - none: 何も表示しない

import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';

class AdvisoryModal {
  /// 必要なら advisory の種類に応じてモーダルを表示する。
  /// rest_or_consult の場合は OK しないと閉じない（barrierDismissible: false）。
  /// 戻り値: ユーザー選択（'ok' / 'accept' / 'decline' / null=未表示）
  static Future<String?> showIfNeeded(
    BuildContext context,
    Advisory advisory,
  ) async {
    switch (advisory.level) {
      case AdvisoryLevel.restOrConsult:
        return await _showRestOrConsult(context, advisory);
      case AdvisoryLevel.deload:
        return await _showDeload(context, advisory);
      case AdvisoryLevel.partialSkip:
        // partial_skip はモーダルではなくバナー想定
        return null;
      case AdvisoryLevel.none:
        return null;
    }
  }

  static Future<String?> _showRestOrConsult(
      BuildContext context, Advisory advisory) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(Icons.medical_services_outlined,
            color: Colors.orange, size: 40),
        title: Text(
          advisory.title ?? '今日はトレーニングを中止しましょう',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              advisory.body ??
                  '痛み等の安全要因が検知されたため、メニュー生成を中止しました。'
                      '医療助言ではありません。痛みや違和感がある場合は医療専門家にご相談ください。',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '本アプリは医療助言・診断・治療を提供しません。',
                style: TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'mobility_easy'),
            child: const Text('軽い可動域運動を見る'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'consult_pro'),
            child: const Text('専門家に相談'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'rest'),
            child: const Text('休養する'),
          ),
        ],
      ),
    );
  }

  static Future<String?> _showDeload(BuildContext context, Advisory advisory) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(Icons.bedtime_outlined,
            color: AppColors.primary, size: 36),
        title: Text(
          advisory.title ?? 'デロードを検討しましょう',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          advisory.body ??
              '直近の RPE が高めです。重量を 10% 下げ、ボリュームを 30% 程度減らした'
                  '回復週を入れることを推奨します。',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'decline'),
            child: const Text('そのまま続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'accept'),
            child: const Text('デロードを適用'),
          ),
        ],
      ),
    );
  }
}

/// partial_skip 用のインラインバナー
class AdvisoryBanner extends StatelessWidget {
  final Advisory advisory;
  final List<String> safetyFlags;

  const AdvisoryBanner({
    super.key,
    required this.advisory,
    this.safetyFlags = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (advisory.level == AdvisoryLevel.none) {
      return const SizedBox.shrink();
    }
    final isPartial = advisory.level == AdvisoryLevel.partialSkip;
    final isDeload = advisory.level == AdvisoryLevel.deload;
    final color = isPartial
        ? Colors.orange
        : (isDeload ? AppColors.primary : Colors.red);
    final icon = isPartial
        ? Icons.warning_amber_outlined
        : (isDeload ? Icons.bedtime_outlined : Icons.error_outline);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (advisory.title != null)
                  Text(
                    advisory.title!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                if (advisory.body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    advisory.body!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
