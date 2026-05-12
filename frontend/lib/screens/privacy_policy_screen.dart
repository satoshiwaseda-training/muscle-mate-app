// プライバシーポリシー画面（計画書 v5 §10.4 + 提出計画書 v1.3 §4.4）
//
// v1.0 提出向け改訂:
// - §4 を「v1.0 では外部 AI 未提供」の文言に差し替え
// - 公開 HTML（GitHub Pages 等）と同じ Markdown ソースから生成する運用
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
        _section('最終更新日', '2026年5月12日（v1.0 提出版）'),
        _section('1. はじめに',
            'Muscle Mate（以下「本アプリ」）は、高林 聡（以下「開発者」）が提供する筋力トレーニング支援アプリケーションです。'
            '本プライバシーポリシーは、お客様の個人情報の取り扱いについて説明します。'),
        _section('2. 収集する情報',
            '本アプリは以下の情報を扱います：\n\n'
            '【端末内に保存される情報】\n'
            '• トレーニング記録（日時、種目、重量、回数、RPE、痛みの有無）\n'
            '• 体力指標（BIG3最大重量、トレーニングレベル）\n'
            '• 任意入力（年齢、性別、体重、怪我履歴、自由記述）\n'
            '• アプリ設定（目標、週間頻度等）\n\n'
            '【サーバーで一時的に処理される情報】\n'
            'メニュー生成リクエストとして上記の一部がサーバーに送信されますが、'
            'サーバーは永続保存しません（§5 参照）。'),
        _section('3. メニュー生成の処理',
            '通常のメニュー生成はサーバー上のルールベースエンジンで完結し、'
            '外部の AI サービスへは情報を送信しません。'),
        _section('4. 外部 AI への送信について（v1.0）',
            '本バージョン（v1.0）では外部 AI への送信は提供していません。'
            'すべてのメニュー生成・アドバイス取得は当社サーバー内のルールエンジンで完結し、'
            '第三者 AI サービスへの送信は発生しません。\n'
            '将来のバージョンで提供する場合は、明示同意とポリシー更新をもってお知らせします。'),
        _section('5. サーバー保存ポリシー',
            'メニュー生成リクエストおよびトレーニング記録を永続化せず、'
            'ログ・APM・データベース・キャッシュにも本文を書きません。\n'
            'サーバーは構造化メタデータ（経路・ステータス・処理時間・リクエスト ID・外部 AI 利用フラグ）'
            'のみを保存します。'),
        _section('6. インフラ事業者によるメタデータ処理',
            '本サービスの提供にあたり、CDN・WAF・ホスティング事業者が、IP アドレス・'
            'User-Agent 等の通信メタデータをセキュリティ・不正利用防止・障害対応の目的で'
            '処理する場合があります。これらは各事業者の規約に従って一定期間保持され得ます。\n'
            '本アプリのサーバープロセスはこれらを永続保存せず、構造化ログにも本文を書き出しません。'),
        _section('7. 端末内データ',
            'すべてのトレーニングデータと任意入力情報は端末内（SharedPreferences / SQLite）'
            'に保存されます。外部サーバーへのデータバックアップは行っていません。\n'
            '設定画面の「アカウントデータを削除」から、本アプリが端末内に保存したすべてのデータを'
            '完全に削除できます。'),
        _section('8. 医療助言の不提供',
            '本アプリは情報提供を目的としたフィットネス支援であり、医療助言・診断・治療を'
            '提供するものではありません。痛みや違和感がある場合は運動を中止し、'
            '医療専門家にご相談ください。\n'
            '持病・術後・妊娠中・若年者は、運動開始前に主治医にご相談ください。'),
        _section('9. 児童のプライバシー',
            '本アプリは 13 歳未満のお子様を対象としていません。初回起動時に 13 歳以上である'
            'ことを自己申告いただきますが、年齢自体は保存しません（チェック状態のみ保存）。'),
        _section('10. 同意撤回',
            '本バージョン（v1.0）では外部 AI への送信を提供していないため、外部 AI に関する'
            '同意取得・撤回フローはありません。\n'
            '端末内データは「アカウントデータを削除」からいつでも完全消去できます。'),
        _section('11. ポリシーの変更',
            '本プライバシーポリシーを変更する場合、アプリ内で通知します。'
            '重要な変更については再度同意をお願いする場合があります。'),
        _section('12. お問い合わせ',
            'プライバシーに関するご質問は、アプリの App Store / Google Play レビュー欄'
            'または開発者の GitHub ページまでお問い合わせください。'),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
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
