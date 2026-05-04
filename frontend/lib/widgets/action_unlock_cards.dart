import 'package:flutter/material.dart';

import '../main.dart' show AppColors, AppGradientButton;

class UnlockCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback? onTap;

  const UnlockCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IgnorePointer(
              child: AppGradientButton(
                onPressed: () {},
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderRadius: BorderRadius.circular(999),
                child: Text(
                  cta == '開く' ? '整える' : cta,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NextBestActionCard extends StatelessWidget {
  final String title;
  final String reason;
  final String expectedBenefit;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? statusText;

  const NextBestActionCard({
    super.key,
    required this.title,
    required this.reason,
    required this.expectedBenefit,
    this.actionLabel,
    this.onAction,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            expectedBenefit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (statusText != null) ...[
            const SizedBox(height: 10),
            Text(
              statusText!,
              style: const TextStyle(
                color: AppColors.warrior,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            AppGradientButton(
              onPressed: onAction,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderRadius: BorderRadius.circular(AppColors.radiusS),
              child: Text(
                actionLabel!,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NextSessionPlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? reasonText;
  final String? statusText;
  final String? rewardText;
  final String? firstActionLabel;
  final VoidCallback? onFirstAction;
  final String? secondActionLabel;
  final VoidCallback? onSecondAction;
  final String? thirdActionLabel;
  final VoidCallback? onThirdAction;

  const NextSessionPlanCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.reasonText,
    this.statusText,
    this.rewardText,
    this.firstActionLabel,
    this.onFirstAction,
    this.secondActionLabel,
    this.onSecondAction,
    this.thirdActionLabel,
    this.onThirdAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppColors.gapL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT SESSION PLAN',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (reasonText != null) ...[
            const SizedBox(height: 6),
            Text(
              reasonText!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          if (statusText != null) ...[
            const SizedBox(height: 10),
            Text(
              statusText!,
              style: const TextStyle(
                color: AppColors.warrior,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (rewardText != null) ...[
            const SizedBox(height: 6),
            Text(
              rewardText!,
              style: const TextStyle(
                color: AppColors.warrior,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (firstActionLabel != null ||
              secondActionLabel != null ||
              thirdActionLabel != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (firstActionLabel != null && onFirstAction != null)
                  AppGradientButton(
                    onPressed: onFirstAction,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderRadius: BorderRadius.circular(AppColors.radiusS),
                    child: Text(
                      firstActionLabel!,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (secondActionLabel != null && onSecondAction != null)
                  AppGradientButton(
                    onPressed: onSecondAction,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderRadius: BorderRadius.circular(AppColors.radiusS),
                    child: Text(
                      secondActionLabel!,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (thirdActionLabel != null && onThirdAction != null)
                  AppGradientButton(
                    onPressed: onThirdAction,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderRadius: BorderRadius.circular(AppColors.radiusS),
                    child: Text(
                      thirdActionLabel!,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ReEntryCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const ReEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppColors.gapL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RE-ENTRY',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
