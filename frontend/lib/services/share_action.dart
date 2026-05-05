// シェアアクションの共通実装
//
// 「RepaintBoundary を画像化して、Web ならダウンロード・モバイルなら
// Native Share Sheet を開く」一連の処理を 1 関数にまとめる。
// share_summary_screen.dart と workout_result_screen.dart の両方から使われる。

import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

/// RepaintBoundary を画像化して、プラットフォーム別の共有処理を行う。
///
/// 戻り値: 成功した場合 true、失敗時 false。
/// SnackBar を呼び出し元の Scaffold に出すため、context を要求する。
Future<bool> captureAndShareCard({
  required BuildContext context,
  required GlobalKey boundaryKey,
  required String fileNamePrefix,
}) async {
  try {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      _toast(context, 'カードを取得できませんでした');
      return false;
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      _toast(context, '画像の生成に失敗しました');
      return false;
    }
    final bytes = byteData.buffer.asUint8List();
    final fileName =
        '${fileNamePrefix}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';

    if (kIsWeb) {
      await downloadBytesAsFile(bytes, fileName);
      _toast(context, '画像をダウンロードしました');
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '#MuscleMate でトレーニング記録中 💪',
      );
    }
    return true;
  } catch (e) {
    _toast(context, '画像の保存に失敗しました: ${e.runtimeType}');
    return false;
  }
}

void _toast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}
