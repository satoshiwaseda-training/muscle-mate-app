import 'package:flutter/material.dart';

import '../main.dart' show AppColors;

class HealthMomentumChip extends StatelessWidget {
  final int lastSessionGain;
  final int weeklyGain;
  final String? decayWarning;
  final String? statusLabel;
  final bool statusCompleted;
  final String? progressText;
  final String? bonusText;
  final bool compact;

  const HealthMomentumChip({
    super.key,
    required this.lastSessionGain,
    required this.weeklyGain,
    this.decayWarning,
    this.statusLabel,
    this.statusCompleted = false,
    this.progressText,
    this.bonusText,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const headline = '健康モメンタム';
    final momentumValue = '+$lastSessionGain';
    final weeklyValue = '今週 +$weeklyGain';
    final explanation =
        compact ? '続けるほど貯まる継続ポイント' : '続けるほど貯まる継続ポイントです。一定量で次回提案が強化されます。';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: compact ? AppColors.surface : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppColors.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (statusLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (statusCompleted
                                  ? AppColors.warrior
                                  : AppColors.surfaceHigh)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusS),
                          border: Border.all(
                            color: (statusCompleted
                                    ? AppColors.warrior
                                    : Colors.white)
                                .withValues(
                                    alpha: statusCompleted ? 0.24 : 0.10),
                          ),
                        ),
                        child: Text(
                          statusLabel!,
                          style: TextStyle(
                            color: statusCompleted
                                ? AppColors.warrior
                                : AppColors.textSecond,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '$headline $momentumValue',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      weeklyValue,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (decayWarning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    decayWarning!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (progressText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    progressText!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusLabel != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (statusCompleted
                              ? AppColors.warrior
                              : AppColors.surfaceHigh)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppColors.radiusS),
                      border: Border.all(
                        color: (statusCompleted
                                ? AppColors.warrior
                                : Colors.white)
                            .withValues(alpha: statusCompleted ? 0.24 : 0.10),
                      ),
                    ),
                    child: Text(
                      statusLabel!,
                      style: TextStyle(
                        color: statusCompleted
                            ? AppColors.warrior
                            : AppColors.textSecond,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'HEALTH MOMENTUM',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.32),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$headline $momentumValue',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weeklyValue,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  explanation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (decayWarning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    decayWarning!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (progressText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    progressText!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (bonusText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    bonusText!,
                    style: const TextStyle(
                      color: AppColors.warrior,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
