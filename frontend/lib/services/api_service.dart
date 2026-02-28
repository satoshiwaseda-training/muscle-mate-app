/// FastAPI バックエンドとの通信サービス
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout_plan.dart';

class ApiService {
  // Codespace で起動した FastAPI のURL（開発時）
  // 本番はプロダクションのURLに切り替える
  static const String _baseUrl = 'http://localhost:8000';

  static Future<WorkoutResponse> generateWorkoutPlan(
      WorkoutRequest request) async {
    final uri = Uri.parse('$_baseUrl/workout/generate');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return WorkoutResponse.fromJson(body);
      } else {
        return WorkoutResponse(
          success: false,
          errorMessage:
              body['detail']?.toString() ?? '不明なエラー (${response.statusCode})',
        );
      }
    } catch (e) {
      return WorkoutResponse(
        success: false,
        errorMessage: '通信エラー: $e',
      );
    }
  }
}
