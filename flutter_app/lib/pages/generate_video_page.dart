import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:flutter_app/services/auth_service.dart';

class GenerateVideoPage extends StatefulWidget {
  final List<dynamic> progressImages;
  final List<Uint8List> imageBytesList;
  final String selectedCategory;
  final double rangeStart;
  final double rangeEnd;
  final double playbackSpeed;
  final String? lastVideoUrl;

  const GenerateVideoPage({
    Key? key,
    required this.progressImages,
    required this.imageBytesList,
    required this.selectedCategory,
    required this.rangeStart,
    required this.rangeEnd,
    required this.playbackSpeed,
    required this.lastVideoUrl,
  }) : super(key: key);

  @override
  State<GenerateVideoPage> createState() => _GenerateVideoPageState();
}

class _GenerateVideoPageState extends State<GenerateVideoPage> {
  bool isGenerating = false;
  String? videoUrl;
  late double rangeStart;
  late double rangeEnd;
  late int fps;

  final List<int> fpsOptions = [5, 10, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    videoUrl = widget.lastVideoUrl;
    rangeStart = widget.rangeStart;
    rangeEnd = widget.rangeEnd;
    fps = fpsOptions.contains(widget.playbackSpeed.toInt())
        ? widget.playbackSpeed.toInt()
        : 10; // default fps
  }

  // 🔥 Reverse index mapping so newest is on the right
  int _mapIndex(int sliderIndex) {
    return widget.progressImages.length - 1 - sliderIndex;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _generateVideo() async {
    setState(() => isGenerating = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? "";
    if (token.isEmpty || widget.progressImages.isEmpty) return;

    final startIdx = _mapIndex(rangeStart.toInt());
    final endIdx = _mapIndex(rangeEnd.toInt());
    final realStart = startIdx < endIdx ? startIdx : endIdx;
    final realEnd = startIdx < endIdx ? endIdx : startIdx;

    final body = {
      "category": widget.selectedCategory,
      "start_index": realStart,
      "end_index": realEnd,
      "fps": fps,
    };

    final url = Uri.parse("https://miloc.awerro.com/api/progress/video/create/");

    try {
      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode(body),
      );

      if (res.statusCode == 403) {
        final data = json.decode(res.body);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Weekly Limit Reached"),
            content: Text(
              data["detail"] ??
                  "You are only allowed to create 10 videos per week on a free plan.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        setState(() => isGenerating = false);
        return;
      }

      if (res.statusCode != 200) {
        _snack("Video generation failed: ${res.statusCode}");
        setState(() => isGenerating = false);
        return;
      }

      final data = json.decode(res.body);
      if (data["video_url"] != null) {
        final absUrl = data["video_url"] as String;
        setState(() => videoUrl = absUrl);
        _snack("Video ready!");
      } else {
        _snack("Response: ${res.body}");
      }
    } catch (e) {
      _snack("Error: $e");
    } finally {
      setState(() => isGenerating = false);
    }
  }

  Future<void> _downloadVideo(Uint8List videoBytes) async {
    final fileName = "progress_${DateTime.now().millisecondsSinceEpoch}.mp4";
    final tempDir = io.Directory.systemTemp;
    final filePath = "${tempDir.path}/$fileName";
    final file = io.File(filePath);
    await file.writeAsBytes(videoBytes);
    await OpenFile.open(filePath);
  }

  Future<void> _shareTo(String platform) async {
    if (videoUrl == null) {
      _snack("No video yet");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? "";

      final res = await http.get(
        Uri.parse(videoUrl!),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode != 200) {
        _snack("Video download failed: ${res.statusCode}");
        return;
      }

      final videoBytes = res.bodyBytes;
      final fileName = "progress_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final tempDir = io.Directory.systemTemp;
      final filePath = "${tempDir.path}/$fileName";
      final file = io.File(filePath);
      await file.writeAsBytes(videoBytes);

      await Share.shareXFiles([XFile(filePath)], text: "Check out my video!");
    } catch (e) {
      _snack("Error sharing video: $e");
    }
  }

  String _formatDate(dynamic img) {
    if (img is Map && img.containsKey("date")) {
      final dt = DateTime.tryParse(img["date"]);
      if (dt != null) return DateFormat("yyyy-MM-dd").format(dt);
    }
    return "?";
  }

  @override
  Widget build(BuildContext context) {
    final displayImage = widget.imageBytesList.isNotEmpty
        ? widget.imageBytesList[_mapIndex(
            rangeStart.toInt().clamp(0, widget.imageBytesList.length - 1))]
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
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
                  icon:
                      const Icon(Icons.arrow_back, size: 32, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
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
                    icon: const Icon(
                      Icons.more_vert,
                      size: 30,
                      color: Colors.black,
                    ),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        final success = await AuthService().logout();
                        if (success) {
                          Navigator.pushReplacementNamed(context, "/login");
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Logout failed, but session cleared."),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.black12,
                  ),
                  child: displayImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.memory(
                            displayImage,
                            fit: BoxFit.cover,
                            height: 400,
                            width: 250,
                          ),
                        )
                      : const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.video_file,
                                size: 80, color: Colors.grey),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select video range:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                RangeSlider(
                  values: RangeValues(rangeStart, rangeEnd),
                  min: 0,
                  max: (widget.progressImages.length - 1).toDouble(),
                  divisions: widget.progressImages.length - 1,
                  labels: RangeLabels(
                    _formatDate(widget.progressImages[_mapIndex(rangeStart.toInt())]),
                    _formatDate(widget.progressImages[_mapIndex(rangeEnd.toInt())]),
                  ),
                  onChanged: (values) {
                    setState(() {
                      rangeStart = values.start;
                      rangeEnd = values.end;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text("Frames per second:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                DropdownButton<int>(
                  value: fps,
                  items: fpsOptions
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text("$e FPS"),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => fps = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  tween: Tween(begin: 1.0, end: isGenerating ? 0.95 : 1.0),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: ElevatedButton.icon(
                        onPressed: isGenerating ? null : _generateVideo,
                        icon: const Icon(Icons.movie, size: 26),
                        label: Text(
                          isGenerating ? "Generating..." : "Generate",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: videoUrl == null
                      ? null
                      : () async {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('token') ?? "";
                          final res = await http.get(Uri.parse(videoUrl!),
                              headers: {"Authorization": "Bearer $token"});
                          if (res.statusCode == 200) {
                            await _downloadVideo(res.bodyBytes);
                          } else {
                            _snack("Download failed: ${res.statusCode}");
                          }
                        },
                  icon: const Icon(Icons.download, size: 26),
                  label: const Text(
                    "Download",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(width: 2, color: Colors.black54),
                    foregroundColor: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: videoUrl == null ? null : () => _shareTo("general"),
                  icon: const Icon(Icons.share, size: 26),
                  label: const Text(
                    "Share",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
