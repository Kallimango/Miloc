import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_gallery_page.dart';
import 'camera_screen.dart';
import 'package:flutter_app/widgets/navbar.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService authService = AuthService();

  bool isLoading = false;
  String errorMessage = "";
  bool rememberMe = false;

  void login() async {
    setState(() => isLoading = true);

    final loginData = await authService.login(
      usernameController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => isLoading = false);

    if (loginData != null && loginData['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', loginData['token']);
      await prefs.setString('username', loginData['username']);
      await prefs.setString('category', loginData['category'] ?? "");
      await prefs.setBool('rememberMe', rememberMe);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Navbar(
            username: loginData['username'],
            category: loginData['category'],
            showScreen: ProgressGalleryPage(
              username: loginData['username'],
              category: loginData['category'],
            ),
            cameraScreen: CameraScreen(),
          ),
        ),
      );
    } else {
      setState(() => errorMessage = "Invalid username or password");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo as an image
            Image.asset(
              'assets/logos/in-app-logo.png', // Path to your logo
              height: 75, // Adjust the height of the logo
              width: 250,  // Adjust the width of the logo (optional)
            ),
            SizedBox(height: 40),
            // Username field
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 20),
            // Password field
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            SizedBox(height: 20),
            // Remember me checkbox
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value ?? false;
                    });
                  },
                ),
                Text("Remember Me", style: TextStyle(fontSize: 16)),
              ],
            ),
            SizedBox(height: 10),
            // Error message display
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            SizedBox(height: 20),
            // Login Button
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Corrected to backgroundColor
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5, // Shadow effect
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Login",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
            SizedBox(height: 20),
            // Register button
            TextButton(
              onPressed: () => Navigator.pushNamed(context, "/register"),
              child: Text(
                "Create an account",
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
