// FastAPI バックエンドとの通信サービス
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout_plan.dart';

class ApiService {
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
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
      return WorkoutResponse(success: false, errorMessage: '通信エラー: $e');
    }
  }

  /// 総挙上重量をエンタメ変換して返す
  static Future<Map<String, dynamic>?> getEntertainment(
      double totalKg) async {
    final uri = Uri.parse('$_baseUrl/workout/entertainment');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'total_kg': totalKg}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
