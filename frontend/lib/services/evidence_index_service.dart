// 論文メタデータのローカルインデックス
// assets/evidence_index.json から起動時にロードして evidence_id → メタデータ を保持
//
// 計画書 v5 §5.4: 同梱は ID/タイトル/著者/年/DOI/ライセンス/出典URL/自作短文サマリのみ
// 本文要約は同梱しない（サーバー内のみで処理）

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/advice.dart';

class EvidenceIndexService {
  static Map<String, EvidenceMeta>? _cache;

  /// 起動時に一度ロード。以降はキャッシュから返す。
  static Future<Map<String, EvidenceMeta>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/evidence_index.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final map = <String, EvidenceMeta>{};
      for (final entry in list) {
        if (entry is Map<String, dynamic>) {
          final meta = EvidenceMeta.fromJson(entry);
          if (meta.evidenceId.isNotEmpty) {
            map[meta.evidenceId] = meta;
          }
        }
      }
      _cache = map;
      return map;
    } catch (_) {
      _cache = const {};
      return _cache!;
    }
  }

  /// 単一 ID 取得（キャッシュ未ロード時は空ロード）
  static Future<EvidenceMeta?> get(String evidenceId) async {
    final map = await load();
    return map[evidenceId];
  }

  /// テスト用: キャッシュリセット
  static void resetCache() => _cache = null;
}
