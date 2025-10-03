import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int currentStep = 0;

  final AuthService authService = AuthService();
  final ApiService apiService = ApiService();

  Map<String, String> formData = {};
  File? profileImage;
  String country = "Detecting...";
  bool isLoading = false;

  /// Try IP-based geolocation first (ipapi.co), fallback to device GPS + reverse geocoding.
  Future<void> detectCountry() async {
    setState(() => country = "Detecting...");
    // 1) Try IP-based API
    try {
      final resp = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final cname = data['country_name'] ?? data['country'] ?? 'Unknown';
        setState(() => country = cname);
        return;
      }
    } catch (_) {
      // ignore and try GPS fallback
    }

    // 2) GPS fallback (if permissions available)
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(() {
          country = placemarks.first.country ?? "Unknown";
        });
      } else {
        setState(() {
          country = "Unknown";
        });
      }
    } catch (e) {
      setState(() {
        country = "Unknown";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    detectCountry();
  }

  Future<void> submitRegistration() async {
    setState(() => isLoading = true);

    formData["country"] = country;
    final result = await authService.register(formData, profileImage);

    setState(() => isLoading = false);

    if (result["statusCode"] == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful! Please log in.")),
      );
      Navigator.pop(context);
    } else {
      final errorMsg = result["body"].toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $errorMsg")),
      );
    }
  }

  void nextPage() {
    if (currentStep < 2) {
      setState(() => currentStep++);
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void prevPage() {
    if (currentStep > 0) {
      setState(() => currentStep--);
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            if (currentStep > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 0),
                  child: IconButton(
                    icon:
                        const Icon(Icons.arrow_back, size: 32, color: Colors.black),
                    onPressed: prevPage,
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StageOne(
                    onNext: (firstName, lastName, profImage) {
                      formData["first_name"] = firstName;
                      formData["last_name"] = lastName;
                      this.profileImage = profImage;
                      nextPage();
                    },
                  ),
                  StageTwo(
                    country: country,
                    onNext: (username, email) {
                      formData["username"] = username;
                      formData["email"] = email;
                      nextPage();
                    },
                  ),
                  StageThree(
                    onSubmit: (password, confirmPassword) async {
                      formData["password"] = password;
                      formData["password2"] = confirmPassword;
                      await submitRegistration();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- STAGE 1 ----------
class StageOne extends StatefulWidget {
  final Function(String, String, File?) onNext;
  const StageOne({Key? key, required this.onNext}) : super(key: key);

  @override
  _StageOneState createState() => _StageOneState();
}

class _StageOneState extends State<StageOne> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  File? profileImage;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        profileImage = File(picked.path);
      });
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage:
                          profileImage != null ? FileImage(profileImage!) : null,
                      child: profileImage == null
                          ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: "First Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: "Last Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onNext(
                          firstNameController.text,
                          lastNameController.text,
                          profileImage,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text("Next",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, "/login"),
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ---------- STAGE 2 ----------
class StageTwo extends StatefulWidget {
  final String country;
  final Function(String, String) onNext;

  const StageTwo({Key? key, required this.country, required this.onNext})
      : super(key: key);

  @override
  _StageTwoState createState() => _StageTwoState();
}

class _StageTwoState extends State<StageTwo> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_circle),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: widget.country == "Detecting..."
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text("Detecting country...")
                          ],
                        )
                      : Text("Country: ${widget.country}",
                          style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onNext(
                          usernameController.text,
                          emailController.text,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text("Next",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, "/login"),
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ---------- STAGE 3 ----------
class StageThree extends StatefulWidget {
  final Function(String, String) onSubmit;

  const StageThree({Key? key, required this.onSubmit}) : super(key: key);

  @override
  _StageThreeState createState() => _StageThreeState();
}

class _StageThreeState extends State<StageThree> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onSubmit(
                          passwordController.text,
                          confirmPasswordController.text,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text("Register",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, "/login"),
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
