import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/pages/progress_gallery_page.dart';
import 'package:flutter_app/pages/camera_screen.dart';
import 'package:flutter_app/widgets/navbar.dart';

// Mock AuthService for logout, replace with your actual implementation
class AuthService {
  Future<bool> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    return true;
  }
}

class FeedbackPage extends StatefulWidget {
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitFeedback() async {
  if (_controller.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Feedback cannot be empty")),
    );
    return;
  }

  setState(() => _isLoading = true);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("token");
  final username = prefs.getString("username") ?? "";
  final category = prefs.getString("category") ?? "";

  final response = await http.post(
    Uri.parse("http://127.0.0.1:8000/api/feedback/create/"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode({"body": _controller.text}),
  );

  setState(() => _isLoading = false);

  if (response.statusCode == 201) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Feedback submitted successfully")),
    );
    _controller.clear();

    // 👇 Navigate straight to ProgressGalleryPage inside Navbar
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Navbar(
          username: username,
          category: category,
          showScreen: ProgressGalleryPage(
            username: username,
            category: category,
          ),
          cameraScreen: CameraScreen(),
          initialIndex: 0, // 👈 Force ProgressGallery first
        ),
      ),
    );
  } else {
    final error = jsonDecode(response.body);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${error['error']}")),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          flexibleSpace: Stack(
            children: [
              Positioned(
                left: 13,
                top: 13,
                bottom: 13,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      size: 32, color: Colors.black),
                  onPressed: () async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString("username") ?? "";
  final category = prefs.getString("category") ?? "";

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => Navbar(
        username: username,
        category: category,
        showScreen: ProgressGalleryPage(
          username: username,
          category: category,
        ),
        cameraScreen: CameraScreen(),
        initialIndex: 0, // 👈 Start on ProgressGallery this time
      ),
    ),
  );
},



                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Image.asset(
                    'assets/logos/in-app-logo.png',
                    width: 160,
                  ),
                ),
              ),
              Positioned(
                right: -5,
                top: 5.5,
                child: Container(
                  height: 75,
                  width: 75,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 30, color: Colors.black),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        final success = await AuthService().logout();
                        if (success) {
                          Navigator.pushReplacementNamed(context, "/login");
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text("Logout failed, but session cleared."),
                            ),
                          );
                          Navigator.pushReplacementNamed(context, "/login");
                        }
                      } else if (value == 'settings') {
                        print('Opening settings...');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          shape: Border(
            bottom: BorderSide(
              color: Colors.black.withOpacity(0.2),
              width: 2.0,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "We’d love to hear your thoughts!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: "Type your feedback here...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitFeedback,
                      child: const Text(
                        "Submit Feedback",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
