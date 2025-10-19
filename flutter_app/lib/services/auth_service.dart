import 'dart:convert';
import 'dart:io'; // For file handling and platform checking
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For checking kIsWeb

class AuthService {
  final String baseUrl = "https://miloc.awerro.com/api";

  /// Login and return token + user details if successful
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("access", data['access']);
        await prefs.setString("refresh", data['refresh']);
        await prefs.setString("username", data['username'] ?? username);
        await prefs.setString("category", data['category'] ?? "");

        return {
          "token": data['access'],
          "username": data['username'] ?? username,
          "category": data['category'] ?? "",
        };
      } else {
        print("Login failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  /// Register with profile image
  Future<Map<String, dynamic>> register(
      Map<String, String> data, File? imageFile) async {
    try {
      var uri = Uri.parse("$baseUrl/auth/register/");
      var request = http.MultipartRequest('POST', uri);

      // Add form data (text fields)
      data.forEach((key, value) {
        request.fields[key] = value;
      });

      // Check if we are on the web or mobile/desktop
      if (imageFile != null) {
        if (kIsWeb) {
          // If on Web, convert image to base64 string and send it
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);

          // Send the base64 image as a string in the form field
          request.fields['profile_picture'] = base64Image;
        } else {
          // If on mobile or desktop, use MultipartFile for the image upload
          request.files.add(
            await http.MultipartFile.fromPath('profile_picture', imageFile.path),
          );
        }
      }

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return {
        "statusCode": response.statusCode,
        "body": jsonDecode(response.body),
      };
    } catch (e) {
      print("Registration error: $e");
      return {
        "statusCode": 500,
        "body": {"error": e.toString()},
      };
    }
  }

  /// Get stored token
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("access");
  }

  /// Get stored username
  Future<String?> getUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("username");
  }

  /// Get stored category
  Future<String?> getCategory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("category");
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access");
    await prefs.remove("refresh");
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("refresh");
  }

  /// 🚀 New Logout Function
  Future<bool> logout() async {
    final refreshToken = await getRefreshToken();
    final accessToken = await getToken();
    if (refreshToken == null || accessToken == null) return false;

    final res = await http.post(
      Uri.parse("$baseUrl/auth/logout/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",   // 👈 add access token here
      },
      body: json.encode({"refresh": refreshToken}),
    );

    if (res.statusCode == 205 || res.statusCode == 200) {
      await clearTokens();
      return true;
    } else {
      await clearTokens(); // still clear locally
      return false;
    }
  }
}
