import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:app_links/app_links.dart';

class WebviewAppScreen extends StatefulWidget {
  const WebviewAppScreen({super.key});

  @override
  State<WebviewAppScreen> createState() => _WebviewAppScreenState();
}

class _WebviewAppScreenState extends State<WebviewAppScreen> {
  late final WebViewController _controller;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isLoading = true;
  int _currentIndex = 0;

  final String _baseUrl = 'https://rtest.epriceoffer.com';

  final List<String> _navUrls = [
    '/home',
    '/categories',
    '/wishlist',
    '/cart',
    '/profile'
  ];

  final List<String> _navSelectors = [
    "a[href='/home']",
    "a[href='/categories']",
    ".header-wishlist-btn",
    ".header-cart-btn",
    "a[href='/profile'], a[href='/login'], .user-profile-btn"
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
    _initDeepLinks();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _updateBottomNavIndex(url);
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('$_baseUrl${_navUrls[0]}'));
  }

  // Update the bottom bar selected index if user navigates inside the webview
  void _updateBottomNavIndex(String url) {
    for (int i = 0; i < _navUrls.length; i++) {
      if (url.contains(_navUrls[i])) {
        if (_currentIndex != i) {
          setState(() {
            _currentIndex = i;
          });
        }
        break;
      }
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial app link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');
    if (uri.host == 'rtest.epriceoffer.com') {
      _controller.loadRequest(uri);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    final selector = _navSelectors[index];
    final targetPath = _navUrls[index];
    
    // We try to click the actual DOM button first (needed for Cart drawer)
    // If it's a hidden dropdown (like Profile), we fallback to our fake anchor trick
    _controller.runJavaScript('''
      var btn = document.querySelector("$selector");
      if (btn && !"$selector".includes("user-profile-btn")) {
        btn.click();
      } else {
        // Fallback: Fake anchor click to trigger React Router directly
        var a = document.createElement('a');
        a.href = '$targetPath';
        document.body.appendChild(a);
        var event = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
        a.dispatchEvent(event);
        a.remove();
      }
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE53935)), // Red to match the website
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onBottomNavTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFFE53935), // Red from the website
            unselectedItemColor: Colors.grey.shade600,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view_rounded),
                label: 'Categories',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border_rounded),
                activeIcon: Icon(Icons.favorite_rounded),
                label: 'Wishlist',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart_outlined),
                activeIcon: Icon(Icons.shopping_cart_rounded),
                label: 'Cart',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
