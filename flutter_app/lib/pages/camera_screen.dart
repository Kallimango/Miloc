import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

  import 'package:image/image.dart' as img;


class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  Uint8List? _webImageBytes;

  bool _showCategories = false;
  String? _selectedCategory;

  List<String> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _fetchCategories();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access');

      if (token == null) throw Exception("No access token found");

      final response = await http.get(
        Uri.parse("https://miloc.awerro.com/api/categories/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _categories = List<String>.from(data.map((cat) => cat["name"]));
          _loadingCategories = false;
        });
      } else {
        throw Exception("Failed to load categories (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      setState(() => _loadingCategories = false);
    }
  }

Future<void> _takePicture() async {
  try {
    await _initializeControllerFuture;
    final image = await _controller!.takePicture();

    if (kIsWeb) {
      // On web (cannot use image package directly), just store original
      _webImageBytes = await image.readAsBytes();
    } else {
      final rawBytes = await image.readAsBytes();

      // Decode with image package
      img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        // ---- Step 1: Correct orientation (so image stands upright) ----
        decoded = img.bakeOrientation(decoded);

        // ---- Step 2: Resize to keep file reasonable ----
        // Keep width <= 1080 px (keeps aspect ratio, so it's portrait if taller)
        decoded = img.copyResize(decoded, width: 1080);

        // ---- Step 3: Compress iteratively to ~0.7 MB ----
        int quality = 90;
        List<int> compressedBytes = img.encodeJpg(decoded, quality: quality);

        while (compressedBytes.length > 700 * 1024 && quality > 50) {
          quality -= 5; // reduce quality gradually
          compressedBytes = img.encodeJpg(decoded, quality: quality);
        }

        // Save compressed image to file
        final compressedFile = File(image.path)
          ..writeAsBytesSync(compressedBytes);

        _capturedImage = XFile(compressedFile.path);

        debugPrint("Final size: ${compressedBytes.length / 1024} KB (quality $quality)");
      }
    }

    setState(() => _showCategories = true);
  } catch (e) {
    debugPrint("Error taking picture: $e");
  }
}

  Future<void> _createProgressImage() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category.")),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access');

      if (token == null) throw Exception("No access token found");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://miloc.awerro.com/api/progress/create/'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['category'] = _selectedCategory!;

      if (kIsWeb && _webImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "image",
            _webImageBytes!,
            filename: "upload.jpg",
          ),
        );
      } else if (_capturedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("image", _capturedImage!.path),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No image selected.")),
        );
        return;
      }

      final sendResponse = await request.send();

      if (sendResponse.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Progress image created successfully!")),
        );

        // Reset so a NEW picture can be taken immediately
        setState(() {
          _showCategories = false;
          _capturedImage = null;
          _webImageBytes = null;
          _selectedCategory = null;
        });

        // Reinitialize camera for the next shot
        await _initializeCamera();
      } else {
        debugPrint("Failed to create progress image: ${sendResponse.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to create progress image.")),
        );
      }
    } catch (e) {
      debugPrint("Error creating progress image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error creating progress image.")),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showCategories
          ? _buildCategorySelection()
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Stack(
                        children: [
                          Positioned.fill(child: CameraPreview(_controller!)),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Padding(padding: EdgeInsetsGeometry.fromLTRB(0, 0, 0, 100), child: GestureDetector(
                            onTap: () => _takePicture(),
                            child: SvgPicture.asset("assets/icons/circle-white.svg", height: 100,),
                          ),))
                            ),
                        ],
                      );
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                ),
    );
  }

  Widget _buildCategorySelection() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: _capturedImage != null
                    ? Image.file(File(_capturedImage!.path))
                    : (kIsWeb && _webImageBytes != null)
                        ? Image.memory(_webImageBytes!)
                        : const SizedBox(),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 3,
                child: GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 18,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: ElevatedButton(
            onPressed: _selectedCategory == null ? null : _createProgressImage,
            child: const Text("Done"),
          ),
        ),
      ],
    );
  }
}
