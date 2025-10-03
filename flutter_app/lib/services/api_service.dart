import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class ApiService {
  final String baseUrl = "http://127.0.0.1:8000/api";

  Future<List<Map<String, dynamic>>> getCategories() async {
    final token = await AuthService().getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/categories/"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }
    return [];
  }

  Future<bool> uploadProgressImage(File imageFile, String categoryId) async {
    final token = await AuthService().getToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/progress/create/"), // ✅ fixed endpoint
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['category'] = categoryId;
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    var res = await request.send();

    if (res.statusCode == 201) {
      // ✅ Allow direct next upload (clear UI state in your widget after this)
      return true;
    }
    return false;
  }
  Future<List<Map<String, dynamic>>> getProgressImages() async {
    final token = await AuthService().getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/progress-images/"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    } else {
      throw Exception("Failed to fetch progress images");
    }
  }
  Future<List<Map<String, dynamic>>> getUserCategoryProgressImages(
    String username, String category) async {
  final token = await AuthService().getToken();
  final res = await http.get(
    Uri.parse("$baseUrl/progress/$username/$category/"),
    headers: {"Authorization": "Bearer $token"},
  );

  if (res.statusCode == 200) {
    return List<Map<String, dynamic>>.from(json.decode(res.body));
  } else if (res.statusCode == 403) {
    throw Exception("Access denied: You can only view your own progress images.");
  } else {
    throw Exception("Failed to fetch progress images");
  }
}


}
