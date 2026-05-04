// 初回起動時の同意画面（提出計画書 v1.3 §4.4 反映版）
//
// v1.0 提出向け:
// - 外部 AI 関連の同意項目を削除（v1.0 では未提供のため）
// - 13 歳以上の自己申告チェックボックス（年齢自体は保存しない）
// - 端末内保存・サーバー一時送信の 2 区分を明示
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show AppColors;
import 'privacy_policy_screen.dart';

class ConsentScreen extends StatefulWidget {
  final VoidCallback onConsented;
  const ConsentScreen({super.key, required this.onConsented});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _ageGatePassed = false;

  Future<void> _accept() async {
    if (!_ageGatePassed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_given', true);
    await prefs.setString('consent_date', DateTime.now().toIso8601String());
    // 13 歳以上の自己申告状態のみ保存（年齢そのものは保存しない）
    await prefs.setBool('age_gate_passed', true);
    // 外部 AI トグルは既定オフ
    await prefs.setBool('external_ai_optin', false);
    widget.onConsented();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.fitness_center,
                    color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Muscle Mate へようこそ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '本アプリの情報の取り扱いについてご確認ください。',
                style: TextStyle(color: AppColors.textSecond, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),

              // 同意項目（v5: 三層分離）
              const _ConsentItem(
                icon: Icons.phone_iphone,
                title: 'トレーニング記録は端末内に保存',
                body: '重量・回数・使用器具などはお客様のデバイス内に保存されます。'
                    '設定からいつでも完全に削除できます。',
              ),
              const SizedBox(height: 12),
              const _ConsentItem(
                icon: Icons.cloud_off_outlined,
                title: 'サーバーは保存しません',
                body: 'メニュー生成のための情報はサーバーで一時的に処理しますが、'
                    'ログ・データベース・キャッシュには保存しません。',
              ),
              const SizedBox(height: 12),
              const _ConsentItem(
                icon: Icons.medical_services_outlined,
                title: '医療助言ではありません',
                body: '本アプリは医療助言・診断・治療を提供しません。'
                    '痛みや違和感がある場合は中止し、医療専門家にご相談ください。',
              ),
              const SizedBox(height: 12),
              const _ConsentItem(
                icon: Icons.delete_outline,
                title: 'いつでも削除',
                body: '設定画面から本アプリが端末内に保存した全データをいつでも削除できます。',
              ),
              const SizedBox(height: 24),

              // 13 歳ゲート（自己申告・年齢非保存）
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _ageGatePassed,
                      onChanged: (v) => setState(() => _ageGatePassed = v ?? false),
                      activeColor: AppColors.primary,
                    ),
                    const Expanded(
                      child: Text(
                        '私は 13 歳以上であることを確認します',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // プライバシーポリシーリンク
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined,
                          color: AppColors.primaryDim, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('プライバシーポリシーを読む',
                            style: TextStyle(
                                color: AppColors.primaryDim,
                                fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.chevron_right,
                          color: AppColors.textSecond, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 同意ボタン
              FilledButton(
                onPressed: _ageGatePassed ? _accept : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.3),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('同意してはじめる'),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _ageGatePassed
                      ? '同意しない場合、アプリを使用できません'
                      : '13 歳以上の確認が必要です',
                  style: TextStyle(
                      color: AppColors.textSecond.withValues(alpha: 0.7),
                      fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _ConsentItem(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.primaryDim, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
