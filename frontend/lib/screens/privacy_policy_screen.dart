// プライバシーポリシー画面
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _PolicyContent(),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('最終更新日', '2026年3月4日'),
        _section('1. はじめに',
            'Muscle Mate（以下「本アプリ」）は、サトシ・ワセダ（以下「開発者」）が提供する筋力トレーニング支援アプリケーションです。'
            '本プライバシーポリシーは、お客様の個人情報の取り扱いについて説明します。'),
        _section('2. 収集する情報',
            '本アプリは以下の情報を収集します：\n\n'
            '• トレーニング記録（日時、種目、重量、回数）\n'
            '• 体力指標（BIG3最大重量、トレーニングレベル）\n'
            '• 使用器具の設定\n'
            '• アプリ設定（トレーニング目標、週間頻度等）\n\n'
            '上記の情報はお客様のデバイス内にのみ保存されます。'),
        _section('3. AIへの情報送信',
            'メニュー生成機能を使用する際、以下の情報がGemini AI（Google LLC）に送信されます：\n\n'
            '• トレーニング目標・レベル\n'
            '• BIG3最大重量（入力した場合）\n'
            '• 使用器具・ターゲット筋群\n\n'
            '氏名・メールアドレス等の個人を特定できる情報は送信されません。\n'
            'Google のプライバシーポリシー: https://policies.google.com/privacy'),
        _section('4. 情報の利用目的',
            '収集した情報は以下の目的にのみ使用します：\n\n'
            '• パーソナライズされたトレーニングメニューの生成\n'
            '• トレーニング履歴の表示・管理\n'
            '• アプリ機能の改善'),
        _section('5. 第三者への提供',
            '開発者はお客様の個人情報を、法令に基づく場合を除き、第三者に販売・提供・開示しません。'),
        _section('6. データの保存',
            'すべてのトレーニングデータはお客様のデバイス内にのみ保存されます。'
            '外部サーバーへのデータバックアップは行っていません。'),
        _section('7. データの削除',
            '設定画面の「アカウントデータを削除」ボタンから、本アプリが保存したすべてのデータを完全に削除できます。'
            'データ削除のリクエストは即座に処理されます。'),
        _section('8. 児童のプライバシー',
            '本アプリは13歳未満のお子様を対象としていません。13歳未満の方の情報を意図的に収集することはありません。'),
        _section('9. ポリシーの変更',
            '本プライバシーポリシーを変更する場合、アプリ内で通知します。重要な変更については再度同意をお願いする場合があります。'),
        _section('10. お問い合わせ',
            'プライバシーに関するご質問は、アプリのApp Store / Google Playレビュー欄または開発者のGitHubページまでお問い合わせください。'),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2040)),
          ),
          child: const Text(
            '本アプリを使用することで、本プライバシーポリシーに同意したものとみなします。',
            style: TextStyle(color: AppColors.textSecond, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.6)),
        ],
      ),
    );
  }
}
