// Web 専用のファイルダウンロード実装。
//
// share_plus の Web 実装は Web Share API（HTTPS 必須・ブラウザ依存）に
// 頼るため、HTTP localhost や Web Share 非対応ブラウザでは失敗する。
// その代替として、blob URL + 隠しアンカー要素の click で直接ダウンロード
// する古典的な手法を使う（macOS Chrome / Safari / Edge / Firefox 全て対応）。
//
// このファイルは web_download_stub.dart と conditional import で切替えられる。

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytesAsFile(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    // メモリリーク防止のため確実に解放
    html.Url.revokeObjectUrl(url);
  }
}
