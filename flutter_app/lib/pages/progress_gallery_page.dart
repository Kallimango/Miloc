import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // for web

import 'package:flutter_app/services/auth_service.dart';

import 'generate_video_page.dart'; // new screen

class ProgressGalleryPage extends StatefulWidget {
  final String username;
  final String category;
  final Function(bool)? onFullscreenChanged;

  const ProgressGalleryPage({
    Key? key,
    required this.username,
    required this.category,
    this.onFullscreenChanged,
  }) : super(key: key);

  @override
  State<ProgressGalleryPage> createState() => _ProgressGalleryPageState();
}

class _ProgressGalleryPageState extends State<ProgressGalleryPage> {
  List<dynamic> progressImages = [];
  List<String> categories = [];
  bool isLoading = true;
  bool isPlaying = false;
  bool showControls = false;
  bool isFullscreen = false;
  int currentIndex = 0;
  Timer? playTimer;

  int fps = 10; // default FPS
  final List<int> fpsOptions = [5, 10, 20, 30, 50];

  String? selectedCategory;
  List<Uint8List> imageBytesList = [];

  double rangeStart = 0;
  double rangeEnd = 0;
  String? lastVideoUrl;
  String? lastVideoRel;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.category;
    fetchCategories();
  }

  @override
  void dispose() {
    playTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? "";
    if (token.isEmpty) return;

    const url = "http://127.0.0.1:8000/api/categories/";

    try {
      final res = await http.get(Uri.parse(url), headers: {
        "Authorization": "Bearer $token",
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fetched = List<String>.from(data.map((item) => item['name']));
        setState(() {
          categories = fetched;
          if (!categories.contains(selectedCategory)) {
            selectedCategory = categories.first;
          }
        });
        fetchProgressImages();
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchProgressImages() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? "";
  if (selectedCategory == null || token.isEmpty) return;

  final url =
      "http://127.0.0.1:8000/api/progress/${widget.username}/${selectedCategory!}/";

  try {
    final res = await http.get(Uri.parse(url), headers: {
      "Authorization": "Bearer $token",
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> images = data["images"];

      List<Uint8List> loadedImages = [];

      for (var img in images) {
        final imageUrl = img["image"];
        Uint8List? imgBytes;

        try {
          // Fetch the encrypted/decrypted image from backend
          final imgRes = await http.get(Uri.parse(imageUrl), headers: {
            "Authorization": "Bearer $token",
          });
          if (imgRes.statusCode == 200) {
            imgBytes = imgRes.bodyBytes;
          } else {
            imgBytes = Uint8List(0);
          }
        } catch (_) {
          imgBytes = Uint8List(0);
        }

        loadedImages.add(imgBytes);
      }

      setState(() {
        progressImages = images.reversed.toList();
        imageBytesList = loadedImages.reversed.toList();
        currentIndex = 0;
        isLoading = false;
        rangeStart = 0;
        rangeEnd =
            (progressImages.isEmpty ? 0 : progressImages.length - 1).toDouble();
      });
    } else {
      setState(() => isLoading = false);
    }
  } catch (_) {
    setState(() => isLoading = false);
  }
}


  void onCategoryChanged(String? newCategory) {
    if (newCategory == null) return;
    setState(() {
      selectedCategory = newCategory;
      isLoading = true;
    });
    fetchProgressImages();
  }

  String formatDate(String rawDate) {
    try {
      final dateTime = DateTime.parse(rawDate);
      return DateFormat("d MMMM yyyy").format(dateTime);
    } catch (_) {
      return rawDate;
    }
  }

  void togglePlay() {
    if (isPlaying) {
      playTimer?.cancel();
      setState(() => isPlaying = false);
    } else {
      setState(() {
        isPlaying = true;
        showControls = false;
      });

      playTimer = Timer.periodic(
        Duration(milliseconds: (1000 / fps).round()), // ✅ based on FPS
        (timer) {
          if (currentIndex > 0) {
            setState(() => currentIndex--);
          } else {
            timer.cancel();
            setState(() => isPlaying = false);
          }
        },
      );
    }
  }

  void toggleFullscreen() {
    setState(() => isFullscreen = !isFullscreen);
    widget.onFullscreenChanged?.call(isFullscreen);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isFullscreen ? Colors.black : Colors.white,
      appBar: isFullscreen
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(85),
              child: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                centerTitle: true,
                flexibleSpace: Stack(
                  children: [
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
                          icon: const Icon(
                            Icons.more_vert,
                            size: 30,
                            color: Colors.black,
                          ),
                          onSelected: (value) async {
                            if (value == 'logout') {
                              final success = await AuthService().logout();
                              if (success) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  "/login",
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Logout failed, but session cleared.",
                                    ),
                                  ),
                                );
                                Navigator.pushReplacementNamed(
                                  context,
                                  "/login",
                                );
                              }
                            } else if (value == 'settings') {
                              print('Opening settings...');
                            } else if (value == 'feedback') {
                              
                                Navigator.pushReplacementNamed(
                                  context,
                                  "/feedback",
                                );
                              
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
                              value: 'feedback',
                              child: Row(
                                children: [
                                  Icon(Icons.feedback),
                                  SizedBox(width: 8),
                                  Text('Feedback'),
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
                    Positioned(
                      right: 35,
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
                          icon: SvgPicture.asset(
                            'assets/icons/progress_images.svg',
                            width: 30,
                            height: 30,
                          ),
                          onSelected: onCategoryChanged,
                          itemBuilder: (context) {
                            return categories
                                .map((category) => PopupMenuItem<String>(
                                      value: category,
                                      child: Text(category),
                                    ))
                                .toList();
                          },
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : progressImages.isEmpty
              ? const Center(
                  child: Text("No progress images yet",
                      style: TextStyle(color: Colors.black)),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    isFullscreen ? 0 : 80,
                    0,
                    isFullscreen ? 0 : 150,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              if (!isPlaying) {
                                setState(() => showControls = !showControls);
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 100),
                                  child: ClipRRect(
                                    borderRadius: isFullscreen
                                        ? BorderRadius.zero
                                        : BorderRadius.circular(10),
                                    child: InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 3.0,
                                      child: imageBytesList.isEmpty ||
                                              currentIndex >=
                                                  imageBytesList.length ||
                                              imageBytesList[currentIndex]
                                                  .isEmpty
                                          ? const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 80,
                                                color: Colors.grey,
                                              ),
                                            )
                                          : Image.memory(
                                              imageBytesList[currentIndex],
                                              width: isFullscreen
                                                  ? MediaQuery.of(context)
                                                      .size
                                                      .width
                                                  : 375,
                                              height: isFullscreen
                                                  ? MediaQuery.of(context)
                                                      .size
                                                      .height
                                                  : 500,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                                // NEW: Share icon above image on right
                                Positioned(
                                  right: 10,
                                  top: 40,
                                  child: IconButton(
                                    icon: SvgPicture.asset(
                                      'icons/share.svg',
                                      width: 30,
                                      height: 30,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GenerateVideoPage(
                                            progressImages: progressImages,
                                            imageBytesList: imageBytesList,
                                            selectedCategory: selectedCategory!,
                                            rangeStart: rangeStart,
                                            rangeEnd: rangeEnd,
                                            playbackSpeed: fps.toDouble(),
                                            lastVideoUrl: lastVideoUrl,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if ((showControls && !isPlaying) ||
                                    isFullscreen)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black26,
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: IconButton(
                                              icon: Icon(
                                                isPlaying
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_fill,
                                                size: 80,
                                                color: Colors.white,
                                              ),
                                              onPressed: togglePlay,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                DropdownButton<int>(
                                                  dropdownColor: Colors.black87,
                                                  value: fps,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  items: fpsOptions
                                                      .map((f) =>
                                                          DropdownMenuItem<
                                                              int>(
                                                            value: f,
                                                            child: Text(
                                                                "$f FPS"),
                                                          ))
                                                      .toList(),
                                                  onChanged: (newFps) {
                                                    if (newFps == null) return;
                                                    setState(() => fps =
                                                        newFps);
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    isFullscreen
                                                        ? Icons.fullscreen_exit
                                                        : Icons.fullscreen,
                                                    color: Colors.white,
                                                  ),
                                                  onPressed: toggleFullscreen,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isFullscreen)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 20),
                          child: Text(
                            progressImages.isNotEmpty &&
                                    progressImages[currentIndex]
                                        .containsKey('date') &&
                                    progressImages[currentIndex]['date'] != null
                                ? formatDate(
                                    progressImages[currentIndex]['date'])
                                : "",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Padding(padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0), child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor:
                              isFullscreen ? Colors.white : Colors.black,
                          inactiveTrackColor:
                              isFullscreen ? Colors.white24 : Colors.black12,
                          thumbColor: Colors.red,
                          overlayColor: Colors.red.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: (progressImages.length - 1 - currentIndex)
                              .toDouble(),
                          min: 0,
                          max: (progressImages.length - 1).toDouble(),
                          divisions: progressImages.length > 1
                              ? progressImages.length - 1
                              : null,
                          onChanged: (value) {
                            setState(() => currentIndex =
                                progressImages.length - 1 - value.toInt());
                          },
                        ),
                      ),),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
    );
  }
}
