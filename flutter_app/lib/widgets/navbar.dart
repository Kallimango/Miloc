import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_app/pages/progress_gallery_page.dart';
class Navbar extends StatefulWidget {
  final String username;
  final String category;
  final Widget showScreen;
  final Widget cameraScreen;
  final int initialIndex; // 👈 flexible starting index

  const Navbar({
    Key? key,
    required this.username,
    required this.category,
    required this.showScreen,
    required this.cameraScreen,
    this.initialIndex = 1, // 👈 default = camera screen
  }) : super(key: key);

  @override
  _NavbarState createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  late int _selectedIndex;
  late PageController _pageController;
  bool _showNavbar = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleFullscreenChanged(bool isFullscreen) {
    setState(() {
      _showNavbar = !isFullscreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _selectedIndex = index),
              children: [
                ProgressGalleryPage(
                  username: widget.username,
                  category: widget.category,
                  onFullscreenChanged: _handleFullscreenChanged,
                ),
                widget.cameraScreen,
              ],
            ),
          ),
          if (_showNavbar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navItem('assets/icons/play-button-black.svg', 0),
                        _navItem('assets/icons/camera-black.svg', 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navItem(dynamic iconOrPath, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.all(isSelected ? 10 : 8),
        child: iconOrPath is IconData
            ? Icon(
                iconOrPath,
                size: isSelected ? 30 : 26,
                color: isSelected ? Colors.black : Colors.grey[700],
              )
            : SvgPicture.asset(
                iconOrPath,
                height: isSelected ? 30 : 26,
                color: isSelected ? Colors.black : Colors.grey[700],
              ),
      ),
    );
  }
}
