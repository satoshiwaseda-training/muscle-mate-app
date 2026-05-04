// FastAPI バックエンドとの通信サービス（計画書 v5）
//
// - X-External-AI-Optin ヘッダで外部 AI 同意状態をサーバーに伝える
//   ※ サーバー側は LLM_PROVIDER=groq とのサーバー側 AND 条件で多重ガード
//      （ヘッダ単独依存ではない・計画書 §6.3）
// - /workout/next はステートレス。サーバーは保存しない
// - タイムアウト: 90秒（外部 AI なしならルール単独で <100ms のため余裕）
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_plan.dart';
import '../models/session_log.dart';
import '../models/advice.dart';

class ApiService {
  // --dart-define=API_BASE_URL=https://your-api.com でプロダクションURLを注入
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const _timeout = Duration(seconds: 90);
  static const _healthTimeout = Duration(seconds: 5);

  static String get baseUrl => _baseUrl;

  /// 外部 AI 補強の同意状態（既定オフ）。設定画面のトグルで切替。
  static Future<bool> _isExternalAiOptin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('external_ai_optin') ?? false;
  }

  static Future<Map<String, String>> _commonHeaders() async {
    final optin = await _isExternalAiOptin();
    return {
      'Content-Type': 'application/json',
      'X-External-AI-Optin': optin ? 'true' : 'false',
    };
  }

  // ── /workout/generate ─────────────────────────────────────────────────────

  static Future<WorkoutResponse> generateWorkoutPlan(
      WorkoutRequest request) async {
    final uri = Uri.parse('$_baseUrl/workout/generate');
    try {
      final headers = await _commonHeaders();
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(request.toJson()))
          .timeout(_timeout);
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return WorkoutResponse.fromJson(body);
      }
      // 422 は独自ハンドラで {"errors":[...]} 形式（input は含まれない）
      final errMsg = _formatServerError(body, response.statusCode);
      return WorkoutResponse(success: false, errorMessage: errMsg);
    } on Exception catch (e) {
      final msg = e.toString().contains('TimeoutException')
          ? 'タイムアウト: サーバーへの接続に失敗しました。ネットワークを確認してください。'
          : '通信エラー: サーバーに接続できません。';
      return WorkoutResponse(success: false, errorMessage: msg);
    }
  }

  // ── /workout/next（ステートレス・外部 AI を呼ばない）──────────────────────

  static Future<NextWorkoutResponse> requestNextWorkout(
      SessionLog lastSession,
      {String? nextDayOfWeek}) async {
    final uri = Uri.parse('$_baseUrl/workout/next');
    try {
      final headers = await _commonHeaders();
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'last_session': lastSession.toJson(),
              if (nextDayOfWeek != null) 'next_day_of_week': nextDayOfWeek,
            }),
          )
          .timeout(_timeout);
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return NextWorkoutResponse.fromJson(body);
      }
      return NextWorkoutResponse(
        success: false,
        errorMessage: _formatServerError(body, response.statusCode),
      );
    } on Exception catch (e) {
      return NextWorkoutResponse(
        success: false,
        errorMessage: e.toString().contains('TimeoutException')
            ? 'タイムアウト: サーバーへの接続に失敗しました。'
            : '通信エラー: サーバーに接続できません。',
      );
    }
  }

  // ── /workout/advice（個別アドバイス・純ルール）────────────────────────────

  static Future<AdviceResponse> getAdvice(WorkoutRequest request) async {
    final uri = Uri.parse('$_baseUrl/workout/advice');
    try {
      final headers = await _commonHeaders();
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(request.toJson()))
          .timeout(_timeout);
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return AdviceResponse.fromJson(body);
      }
      return AdviceResponse(
        success: false,
        errorMessage: _formatServerError(body, response.statusCode),
      );
    } on Exception catch (e) {
      return AdviceResponse(
        success: false,
        errorMessage: e.toString().contains('TimeoutException')
            ? 'タイムアウト: サーバーへの接続に失敗しました。'
            : '通信エラー: サーバーに接続できません。',
      );
    }
  }

  // ── /workout/entertainment（既存維持）────────────────────────────────────

  static Future<Map<String, dynamic>?> getEntertainment(double totalKg) async {
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

  /// ヘルスチェック（バックエンド接続判定用）
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_healthTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isOnline() => checkHealth();

  // ── ヘルパー ──────────────────────────────────────────────────────────────

  static String _formatServerError(Map<String, dynamic> body, int status) {
    if (body['errors'] is List) {
      final errs = body['errors'] as List;
      if (errs.isNotEmpty && errs.first is Map) {
        final first = errs.first as Map;
        final msg = first['msg']?.toString() ?? '';
        if (msg.isNotEmpty) return '入力エラー: $msg';
      }
    }
    if (body['detail'] != null) return body['detail'].toString();
    return 'サーバーエラー ($status)';
  }
}
