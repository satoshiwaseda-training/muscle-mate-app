// FastAPI バックエンドとの通信サービス
// 本番URL: 環境変数 API_BASE_URL（--dart-define で注入）
// タイムアウト: 30秒
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout_plan.dart';

class ApiService {
  // --dart-define=API_BASE_URL=https://your-api.com でプロダクションURLを注入
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const _timeout = Duration(seconds: 30);

  static Future<WorkoutResponse> generateWorkoutPlan(
      WorkoutRequest request) async {
    final uri = Uri.parse('$_baseUrl/workout/generate');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return WorkoutResponse.fromJson(body);
      }
      return WorkoutResponse(
        success: false,
        errorMessage:
            body['detail']?.toString() ?? '不明なエラー (${response.statusCode})',
      );
    } on Exception catch (e) {
      final msg = e.toString().contains('TimeoutException')
          ? 'タイムアウト: AIサーバーへの接続に失敗しました。\nネットワークを確認してください。'
          : '通信エラー: サーバーに接続できません。';
      return WorkoutResponse(success: false, errorMessage: msg);
    }
  }

  /// 総挙上重量をエンタメ変換して返す
  static Future<Map<String, dynamic>?> getEntertainment(
      double totalKg) async {
    final uri = Uri.parse('$_baseUrl/workout/entertainment');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'total_kg': totalKg}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// ヘルスチェック（オフライン判定用）
  static Future<bool> isOnline() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
