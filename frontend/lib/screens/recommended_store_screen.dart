import 'package:flutter/material.dart';

import '../main.dart' show AppColors;

class RecommendedStoreScreen extends StatelessWidget {
  const RecommendedStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('おすすめストア'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _StoreSection(
            title: '今日のおすすめ',
            items: [
              _StoreItemData(
                title: '回復ラウンジパス',
                subtitle: 'トレ後の回復に合うサポートを選べます',
                context: '今の状態に合わせて1つ選びやすい',
              ),
              _StoreItemData(
                title: '次回提案ブースト',
                subtitle: '次回の最適提案を強化',
                context: '今週の流れを切らさず整えたい日に',
              ),
            ],
          ),
          SizedBox(height: 16),
          _StoreSection(
            title: '回復サポート',
            items: [
              _StoreItemData(
                title: '睡眠リカバリー',
                subtitle: '今夜の休み方を短く確認',
                context: '回復不足を感じる日におすすめ',
              ),
              _StoreItemData(
                title: '栄養リカバリー',
                subtitle: 'トレ後の補給を1つ確認',
                context: 'トレ後の回復に合う',
              ),
            ],
          ),
          SizedBox(height: 16),
          _StoreSection(
            title: 'トレーニング強化',
            items: [
              _StoreItemData(
                title: '下半身フォーカス提案',
                subtitle: '脚トレの流れを整える',
                context: '今週の下半身強化におすすめ',
              ),
              _StoreItemData(
                title: '上半身バランス提案',
                subtitle: '胸と背中の配分を整える',
                context: '週の偏りを戻したい日に',
              ),
            ],
          ),
          SizedBox(height: 16),
          _StoreSection(
            title: '会員特典',
            items: [
              _StoreItemData(
                title: 'プレミアム回復メモ',
                subtitle: '回復ラウンジを自動で表示',
                context: 'サポート選択を毎回ラクにしたい人向け',
              ),
              _StoreItemData(
                title: '強化版 NextBestAction',
                subtitle: '週目標と回復に合わせて提案',
                context: '次の1手を迷わず決めたい日に',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreSection extends StatelessWidget {
  final String title;
  final List<_StoreItemData> items;

  const _StoreSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StoreItemCard(item: item),
            )),
      ],
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  final _StoreItemData item;

  const _StoreItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.context,
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreItemData {
  final String title;
  final String subtitle;
  final String context;

  const _StoreItemData({
    required this.title,
    required this.subtitle,
    required this.context,
  });
}
