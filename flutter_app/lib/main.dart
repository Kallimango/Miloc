import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/navbar.dart'; // Import Navbar
import 'pages/camera_screen.dart'; // Import CameraScreen
import 'pages/progress_gallery_page.dart'; // Import ProgressGalleryPage
import 'pages/login_screen.dart';
import 'pages/register_screen.dart';
import 'pages/feedback_page.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  
  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
  theme: ThemeData(fontFamily: 'InstrumentSant'),
  debugShowCheckedModeBanner: false,
  home: SplashScreen(),
  routes: {
    '/login': (context) => LoginScreen(),
    '/register': (context) => RegisterScreen(),
    '/feedback': (context) => FeedbackPage(),
  },
  onGenerateRoute: (settings) {
  if (settings.name == "/progress_gallery") {
    final args = settings.arguments as Map<String, dynamic>?;

    return MaterialPageRoute(
      builder: (context) => ProgressGalleryPage(
        username: args?['username'] ?? "",
        category: args?['category'] ?? "",
      ),
    );
  }
  return null;
},

);

  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _username;
  String? _category;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final storedUsername = prefs.getString('username');
    final storedCategory = prefs.getString('category');
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    setState(() {
      _username = storedUsername;
      _category = storedCategory;
      _isLoggedIn = rememberMe && token != null && token.isNotEmpty && storedUsername != null;
      _isLoading = false;
    });

    if (_isLoggedIn) {
      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => Navbar(
      username: _username!,
      category: _category ?? "",
      showScreen: ProgressGalleryPage(
        username: _username!,
        category: _category ?? "",
      ),
      cameraScreen: CameraScreen(),
      initialIndex: 1, // 👈 Camera as default
    ),
  ),
);

    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(); // Navigation handled in _checkLogin
  }
}
