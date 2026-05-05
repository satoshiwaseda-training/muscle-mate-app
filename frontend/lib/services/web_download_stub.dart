// Web 以外向けスタブ（モバイルではこちらが選ばれる）。
//
// share_summary_screen.dart からの conditional import で
// 'web_download_web.dart' if (dart.library.html) を経由する。
// モバイル側ではこの関数は呼ばれない（kIsWeb 分岐済）。

import 'dart:typed_data';

Future<void> downloadBytesAsFile(Uint8List bytes, String fileName) async {
  // モバイルでは share_plus 経由で Native Share Sheet を使うため、
  // この関数は呼ばれない。万一呼ばれた場合は明示的に失敗させる。
  throw UnsupportedError(
    'downloadBytesAsFile は Web ビルドでのみ呼び出せます',
  );
}
