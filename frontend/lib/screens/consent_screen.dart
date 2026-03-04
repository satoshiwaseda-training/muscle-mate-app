// 初回起動時の同意画面（Apple審査必須: 健康データ利用の同意）
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
  bool _policyRead = false;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_given', true);
    await prefs.setString('consent_date', DateTime.now().toIso8601String());
    widget.onConsented();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // アイコン
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
                '本アプリを使用するにあたり、以下の情報の取り扱いについてご確認ください。',
                style: TextStyle(color: AppColors.textSecond, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),

              // 同意項目
              _ConsentItem(
                icon: Icons.fitness_center,
                title: 'トレーニングデータの記録',
                body: '重量・回数・使用器具などのトレーニング記録を、お客様のデバイス内に保存します。',
              ),
              const SizedBox(height: 12),
              _ConsentItem(
                icon: Icons.psychology,
                title: 'AIへのデータ送信',
                body: 'メニュー生成時に、トレーニング設定（目標・レベル・BIG3 MAX等）をGemini AIに送信します。氏名・連絡先等の個人情報は送信されません。',
              ),
              const SizedBox(height: 12),
              _ConsentItem(
                icon: Icons.delete_outline,
                title: 'データ削除の権利',
                body: '設定画面からいつでも全データを削除できます。',
              ),
              const SizedBox(height: 28),

              // プライバシーポリシーリンク
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  );
                  setState(() => _policyRead = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2040)),
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
              const Spacer(),

              // 同意ボタン
              FilledButton(
                onPressed: _accept,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
                  '同意しない場合、アプリを使用できません',
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
        border: Border.all(color: const Color(0xFF2A2040)),
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
