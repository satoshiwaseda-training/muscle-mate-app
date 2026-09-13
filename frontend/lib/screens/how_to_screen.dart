// やり方（使い方動画）画面
//
// ホーム画面のサイドメニュー最上段と設定画面の最上段から開く。
// これまでに作成してきた「やり方」動画（YouTube）をこの画面に並べて見せる。
//
// ── 動画の追加方法 ───────────────────────────────────────────────────────────
//   下の kHowToVideos に HowToVideo を追加し、youtubeUrl に YouTube の URL を
//   入れるだけでよい。youtubeUrl が null の項目は「準備中」として表示される。
//   対応している URL 形式:
//     https://www.youtube.com/watch?v=XXXXXXXXXXX
//     https://youtu.be/XXXXXXXXXXX
//     https://www.youtube.com/shorts/XXXXXXXXXXX
//     https://www.youtube.com/embed/XXXXXXXXXXX
//   動画 ID が取り出せた項目はサムネイル付きで表示し、タップすると YouTube
//   アプリ（無ければブラウザ）で再生する。
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show AppColors;

/// やり方動画 1 本分の情報。
class HowToVideo {
  final String title;
  final String description;
  final IconData icon;

  /// YouTube の動画 URL。null の間は「準備中」として表示する。
  final String? youtubeUrl;

  const HowToVideo({
    required this.title,
    required this.description,
    required this.icon,
    this.youtubeUrl,
  });

  bool get isAvailable => youtubeUrl != null && youtubeUrl!.trim().isNotEmpty;

  /// URL から取り出した YouTube 動画 ID（取り出せなければ null）。
  String? get videoId => youtubeVideoId(youtubeUrl);

  /// YouTube が公開しているサムネイル画像の URL。
  String? get thumbnailUrl {
    final id = videoId;
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }
}

/// YouTube の各種 URL 形式から 11 文字の動画 ID を取り出す。
/// YouTube 以外の URL や ID が読めない URL は null を返す。
String? youtubeVideoId(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;

  final host =
      uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? id;
  if (host == 'youtu.be') {
    if (segments.isNotEmpty) id = segments.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) {
      id = v;
    } else if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live', 'v'}.contains(segments[0])) {
      id = segments[1];
    }
  }

  if (id == null) return null;
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
}

/// 画面に並べる動画の一覧。YouTube のリンクが用意でき次第 youtubeUrl を埋める。
const List<HowToVideo> kHowToVideos = [
  HowToVideo(
    title: 'はじめに：アプリの基本的な使い方',
    description: 'ホーム画面の見方と、毎日の「メニューを作る → 記録する」の流れ',
    icon: Icons.play_circle_outline,
  ),
  HowToVideo(
    title: '今日のメニューを作る',
    description: '目的・使える時間・鍛えたい部位を選んでメニューを提案してもらう手順',
    icon: Icons.fitness_center,
  ),
  HowToVideo(
    title: 'トレーニングを記録する',
    description: 'セットごとの重量・回数の入力と、終了後の成果画面の見方',
    icon: Icons.edit_note,
  ),
  HowToVideo(
    title: '履歴とカレンダーを見る',
    description: '過去の記録の確認方法と、鍛えた部位の表示について',
    icon: Icons.history,
  ),
  HowToVideo(
    title: '実績をシェアする',
    description: '持ち上げた合計重量を画像にして SNS で共有する方法',
    icon: Icons.ios_share,
  ),
  HowToVideo(
    title: '設定をカスタマイズする',
    description: '目的・運動経験・MAX 重量・使える器具の設定方法',
    icon: Icons.settings_outlined,
  ),
];

class HowToScreen extends StatelessWidget {
  /// 表示する動画一覧。通常は kHowToVideos を使う（テスト用に差し替え可能）。
  final List<HowToVideo> videos;

  const HowToScreen({super.key, this.videos = kHowToVideos});

  Future<void> _openVideo(BuildContext context, HowToVideo video) async {
    final url = video.youtubeUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url.trim());

    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Exception {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('動画を開けませんでした。通信環境をご確認ください'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = videos.where((v) => v.isAvailable).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('やり方')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _IntroCard(
            availableCount: availableCount,
            totalCount: videos.length,
          ),
          const SizedBox(height: 16),
          for (final video in videos) ...[
            _VideoCard(
              video: video,
              onTap:
                  video.isAvailable ? () => _openVideo(context, video) : null,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── 部品 ──────────────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  final int availableCount;
  final int totalCount;

  const _IntroCard({
    required this.availableCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final message = availableCount == 0
        ? '動画は準備中です。順次追加していきますので、もうしばらくお待ちください。'
        : 'タップすると YouTube で動画が開きます。動画は順次追加していきます。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ondemand_video, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                '動画で使い方をチェック',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppColors.radiusS),
            ),
            child: Text(
              '公開中 $availableCount 本 / 全 $totalCount 本',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final HowToVideo video;
  final VoidCallback? onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = video.isAvailable;
    final thumbnailUrl = video.thumbnailUrl;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusL),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusL),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (available && thumbnailUrl != null)
                _Thumbnail(url: thumbnailUrl),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: available
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppColors.radiusS),
                      ),
                      child: Icon(
                        video.icon,
                        color: available
                            ? AppColors.primary
                            : AppColors.textSecond,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            video.description,
                            style: const TextStyle(
                              color: AppColors.textSecond,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          available
                              ? const _StatusChip(
                                  icon: Icons.play_arrow_rounded,
                                  label: 'YouTube で見る',
                                  color: AppColors.primaryDim,
                                )
                              : const _StatusChip(
                                  icon: Icons.schedule,
                                  label: '準備中',
                                  color: AppColors.textSecond,
                                ),
                        ],
                      ),
                    ),
                    if (available)
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primaryDim.withValues(alpha: 0.6),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppColors.radiusL),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.surfaceHigh,
                child: Center(
                  child: Icon(Icons.ondemand_video,
                      color: AppColors.textSecond, size: 36),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
