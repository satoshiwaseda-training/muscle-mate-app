import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muscle_mate/screens/how_to_screen.dart';

void main() {
  group('youtubeVideoId', () {
    const id = 'dQw4w9WgXcQ';

    test('watch?v= 形式から ID を取り出せる', () {
      expect(youtubeVideoId('https://www.youtube.com/watch?v=$id'), id);
      expect(youtubeVideoId('https://m.youtube.com/watch?v=$id&t=30s'), id);
    });

    test('youtu.be 短縮形式から ID を取り出せる', () {
      expect(youtubeVideoId('https://youtu.be/$id'), id);
      expect(youtubeVideoId('https://youtu.be/$id?si=abcdef'), id);
    });

    test('shorts / embed / live 形式から ID を取り出せる', () {
      expect(youtubeVideoId('https://www.youtube.com/shorts/$id'), id);
      expect(youtubeVideoId('https://www.youtube.com/embed/$id'), id);
      expect(youtubeVideoId('https://youtube.com/live/$id'), id);
    });

    test('前後の空白があっても取り出せる', () {
      expect(youtubeVideoId('  https://youtu.be/$id \n'), id);
    });

    test('YouTube 以外や ID が読めない URL は null', () {
      expect(youtubeVideoId(null), isNull);
      expect(youtubeVideoId(''), isNull);
      expect(youtubeVideoId('https://example.com/watch?v=$id'), isNull);
      expect(youtubeVideoId('https://www.youtube.com/'), isNull);
      expect(youtubeVideoId('https://www.youtube.com/watch?v=short'), isNull);
      expect(youtubeVideoId('https://www.youtube.com/playlist?list=PLxyz'),
          isNull);
    });
  });

  group('HowToVideo', () {
    test('URL 未設定の動画は準備中扱いでサムネイルも無い', () {
      const video = HowToVideo(
        title: 't',
        description: 'd',
        icon: Icons.play_circle_outline,
      );
      expect(video.isAvailable, isFalse);
      expect(video.videoId, isNull);
      expect(video.thumbnailUrl, isNull);
    });

    test('URL 設定済みの動画は YouTube のサムネイル URL を返す', () {
      const video = HowToVideo(
        title: 't',
        description: 'd',
        icon: Icons.play_circle_outline,
        youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
      );
      expect(video.isAvailable, isTrue);
      expect(video.thumbnailUrl,
          'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });
  });

  group('HowToScreen', () {
    testWidgets('URL 未設定の項目は「準備中」として表示される', (tester) async {
      const videos = [
        HowToVideo(
          title: 'テスト動画',
          description: 'テスト用の説明',
          icon: Icons.play_circle_outline,
        ),
      ];
      await tester.pumpWidget(
        const MaterialApp(home: HowToScreen(videos: videos)),
      );

      expect(find.text('やり方'), findsOneWidget);
      expect(find.text('テスト動画'), findsOneWidget);
      expect(find.text('テスト用の説明'), findsOneWidget);
      expect(find.text('準備中'), findsOneWidget);
      expect(find.text('公開中 0 本 / 全 1 本'), findsOneWidget);
      expect(find.text('YouTube で見る'), findsNothing);
    });

    testWidgets('既定の一覧が表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HowToScreen()));

      expect(kHowToVideos, isNotEmpty);
      expect(find.text(kHowToVideos.first.title), findsOneWidget);
      expect(find.text('公開中 0 本 / 全 ${kHowToVideos.length} 本'), findsOneWidget);
    });
  });
}
