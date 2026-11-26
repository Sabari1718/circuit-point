import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String url;
  final String selector;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.url,
    required this.selector,
  });
}

class WebviewAppScreen extends StatefulWidget {
  const WebviewAppScreen({super.key});

  @override
  State<WebviewAppScreen> createState() => _WebviewAppScreenState();
}

class _WebviewAppScreenState extends State<WebviewAppScreen> {
  late final WebViewController _controller;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  double _loadingProgress = 0.0;
  bool _hasError = false;
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  final String _baseUrl = 'https://shop.circuitpointcare.com';

  final List<_NavItemData> _navItems = const [
    _NavItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      url: '/home',
      selector: "a[href='/home']",
    ),
    _NavItemData(
      label: 'Categories',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      url: '/categories',
      selector: "a[href='/categories']",
    ),
    _NavItemData(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      url: '/products',
      selector: "a[href='/products']",
    ),
    _NavItemData(
      label: 'Wishlist',
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      url: '/wishlist',
      selector: ".header-wishlist-btn",
    ),
    _NavItemData(
      label: 'Cart',
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart_rounded,
      url: '/cart',
      selector: ".header-cart-btn",
    ),
    _NavItemData(
      label: 'My Account',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      url: '/profile',
      selector: ".user-profile-btn",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initWebView();
    _initDeepLinks();
  }

  void _initWebView() {
    final navigationDelegate = NavigationDelegate(
      onProgress: (int progress) {
        setState(() {
          _loadingProgress = progress / 100.0;
        });
        if (progress > 50) {
          _injectMobileFixes();
        }
      },
      onPageStarted: (String url) {
        setState(() {
          _hasError = false;
          _updateBottomNavIndex(url);
        });
        _controller.runJavaScript('window.scrollTo(0, 0);');
      },
      onPageFinished: (String url) {
        _injectMobileFixes();
      },
      onWebResourceError: (WebResourceError error) {
        // Only trigger full connection failure if the main HTML frame itself fails
        if (error.isForMainFrame == true) {
          debugPrint(
            'WebView Main Frame Error: ${error.description} (code: ${error.errorCode})',
          );
          setState(() {
            _hasError = true;
          });
        }
        // Subresource errors are safely ignored here
      },
      onNavigationRequest: (NavigationRequest request) async {
        final uri = Uri.parse(request.url);

        // Handle UPI, WhatsApp, Tel, Mailto, and custom payment schemes (like Flipkart)
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          try {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              await launchUrl(
                uri,
                mode: LaunchMode.externalNonBrowserApplication,
              );
            }
          } catch (e) {
            debugPrint(
              'Could not launch external URL: ${request.url}, error: $e',
            );
          }
          return NavigationDecision.prevent;
        }

        return NavigationDecision.navigate;
      },
    );

    if (navigationDelegate.platform is AndroidNavigationDelegate) {
      final androidNav =
          navigationDelegate.platform as AndroidNavigationDelegate;
      androidNav.setOnSSlAuthError((error) {
        if (error is AndroidSslAuthError) {
          error.proceed();
        }
      });
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(navigationDelegate);

    if (_controller.platform is AndroidWebViewController) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
      androidController.setOnShowFileSelector((
        FileSelectorParams params,
      ) async {
        try {
          FileType fileType = FileType.any;
          List<String>? allowedExtensions;

          final accepts = params.acceptTypes;
          final bool acceptsImages = accepts.any(
            (t) => t.toLowerCase().contains('image'),
          );
          final bool acceptsPdf = accepts.any(
            (t) => t.toLowerCase().contains('pdf'),
          );

          if (acceptsImages && !acceptsPdf) {
            fileType = FileType.image;
          } else if (acceptsPdf && !acceptsImages) {
            fileType = FileType.custom;
            allowedExtensions = ['pdf'];
          } else if (acceptsPdf && acceptsImages) {
            fileType = FileType.custom;
            allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
          }

          List<PlatformFile> pickedFiles = [];
          if (params.mode == FileSelectorMode.openMultiple) {
            pickedFiles = await FilePicker.pickFiles(
              type: fileType,
              allowedExtensions: allowedExtensions,
            );
          } else {
            final single = await FilePicker.pickFile(
              type: fileType,
              allowedExtensions: allowedExtensions,
            );
            if (single != null) {
              pickedFiles = [single];
            }
          }

          if (pickedFiles.isNotEmpty) {
            final uris = <String>[];
            for (final f in pickedFiles) {
              if (f.path != null && f.path!.isNotEmpty) {
                uris.add(Uri.file(f.path!).toString());
              } else if (f.uri.toString().isNotEmpty) {
                uris.add(f.uri.toString());
              }
            }
            return uris;
          }
        } catch (e) {
          debugPrint('File picker error: $e');
        }
        return [];
      });
    }

    _controller.loadRequest(Uri.parse('$_baseUrl${_navItems[0].url}'));
  }

  void _injectMobileFixes() {
    const js = '''
    (function() {
      // 1. Inject Styles without any blur filters (prevents Chromium blurry rendering bug)
      var style = document.getElementById('circuit-point-custom-css');
      if (!style) {
        style = document.createElement('style');
        style.id = 'circuit-point-custom-css';
        document.head.appendChild(style);
      }
      style.textContent = `
          /* Subtle Translucent Backdrop for Popover */
          .user-card-backdrop {
            display: none;
            position: fixed !important;
            inset: 0 !important;
            background: rgba(0, 0, 0, 0.28) !important;
            z-index: 99998 !important;
            animation: backdropFadeIn 0.15s ease-out !important;
          }
          .user-card-backdrop.active {
            display: block !important;
          }
          @keyframes backdropFadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }

          /* Exact Web My Account Dropdown Card */
          .user-dropdown-card {
            position: fixed !important;
            bottom: 82px !important;
            right: 12px !important;
            width: 245px !important;
            max-width: calc(100vw - 24px) !important;
            background: #ffffff !important;
            border: 1px solid #e2e8f0 !important;
            border-radius: 14px !important;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15), 0 3px 8px rgba(0, 0, 0, 0.06) !important;
            z-index: 99999 !important;
            padding: 8px 6px !important;
            box-sizing: border-box !important;
            animation: dropdownPopUp 0.18s cubic-bezier(0.16, 1, 0.3, 1) !important;
            transform-origin: bottom right !important;
          }

          @keyframes dropdownPopUp {
            from {
              opacity: 0;
              transform: translateY(8px) scale(0.96);
            }
            to {
              opacity: 1;
              transform: translateY(0) scale(1);
            }
          }

          /* Exact Web Header: White background, dark title, gray subtitle */
          .user-dropdown-header {
            background: transparent !important;
            border-bottom: 1px solid #f1f5f9 !important;
            border-radius: 0 !important;
            padding: 6px 10px 8px 10px !important;
            margin-bottom: 4px !important;
          }

          .user-dropdown-name {
            font-size: 14.5px !important;
            font-weight: 700 !important;
            color: #0f172a !important;
            letter-spacing: -0.2px !important;
            margin: 0 !important;
          }

          .user-dropdown-email {
            font-size: 12px !important;
            font-weight: 500 !important;
            color: #64748b !important;
            margin-top: 2px !important;
            word-break: break-all !important;
            white-space: normal !important;
          }

          /* Exact Web Dropdown Menu Items */
          .user-dropdown-item {
            font-size: 13.5px !important;
            font-weight: 600 !important;
            padding: 8.5px 12px !important;
            border-radius: 8px !important;
            display: flex !important;
            align-items: center !important;
            gap: 10px !important;
            color: #1e293b !important;
            text-decoration: none !important;
            cursor: pointer !important;
            margin: 1px 0 !important;
            width: 100% !important;
            box-sizing: border-box !important;
            transition: background 0.12s ease !important;
          }

          .user-dropdown-item:active {
            background: #f1f5f9 !important;
          }

          .user-dropdown-item i {
            font-size: 14px !important;
            width: 18px !important;
            text-align: center !important;
          }

          .user-dropdown-item.logout {
            color: #dc2626 !important;
          }
          .user-dropdown-item.logout i {
            color: #dc2626 !important;
          }

          @media (max-width: 991px) {
            /* Profile Page - Native Web Layout with bottom spacing for floating bar */
            .profile-page-wrapper {
              padding-bottom: 95px !important;
            }

            /* ============================================================== */
            /* FLIPKART-STYLE TOP APP BAR & SEARCH BAR REDESIGN               */
            /* ============================================================== */

            /* Remove Voxo Logo Images Completely */
            .brand-logo-img,
            .login-brand-logo-img,
            .footer-brand-tag {
              display: none !important;
              width: 0 !important;
              height: 0 !important;
              opacity: 0 !important;
              visibility: hidden !important;
              position: absolute !important;
              pointer-events: none !important;
            }

            /* Luxury Flipkart-Style Header Container */
            .app-header {
              height: auto !important;
              min-height: auto !important;
              background: #ffffff !important;
              box-shadow: 0 4px 20px rgba(0, 0, 0, 0.06) !important;
              border-bottom: 1px solid #f1f5f9 !important;
              position: sticky !important;
              top: 0 !important;
              z-index: 1000 !important;
              padding: 0 !important;
            }

            .app-header-inner {
              display: flex !important;
              flex-direction: column !important;
              padding: 10px 14px 12px !important;
              gap: 10px !important;
              height: auto !important;
              min-height: auto !important;
              width: 100% !important;
              box-sizing: border-box !important;
            }

            /* Row 1: Brand & Delivery Pill */
            .header-left-group {
              display: flex !important;
              align-items: center !important;
              justify-content: space-between !important;
              width: 100% !important;
              margin: 0 !important;
            }

            /* Remove Home & Products navigation buttons completely from top app bar */
            .main-nav {
              display: none !important;
            }

            /* Hide redundant header actions and notification bell icon on mobile */
            .header-actions,
            .notification-center-container,
            .header-notification-btn {
              display: none !important;
            }

            /* VA Groups Brand Section - Positioned First & Styled Gethu */
            .brand-section {
              display: inline-flex !important;
              align-items: center !important;
              gap: 8px !important;
              text-decoration: none !important;
            }

            /* Microchip Electronics Emblem Badge before VA Groups */
            .va-brand-chip {
              display: inline-flex !important;
              align-items: center !important;
              justify-content: center !important;
              width: 32px !important;
              height: 32px !important;
              min-width: 32px !important;
              border-radius: 10px !important;
              background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%) !important;
              color: #ffffff !important;
              font-size: 15px !important;
              box-shadow: 0 4px 12px rgba(239, 68, 68, 0.35) !important;
            }

            .brand-text {
              font-size: 20px !important;
              font-weight: 900 !important;
              letter-spacing: -0.6px !important;
              color: #0f172a !important;
              display: inline-flex !important;
              align-items: center !important;
              gap: 3px !important;
              line-height: 1 !important;
            }

            .brand-text span {
              color: #ef4444 !important;
              font-weight: 900 !important;
            }

            /* Flipkart-Style Delivery / Genuine Store Pill */
            .header-delivery-pill {
              display: inline-flex !important;
              align-items: center !important;
              gap: 5px !important;
              background: #f8fafc !important;
              border: 1.2px solid #e2e8f0 !important;
              border-radius: 20px !important;
              padding: 4px 11px !important;
              font-size: 11px !important;
              font-weight: 700 !important;
              color: #475569 !important;
              box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04) !important;
            }

            .header-delivery-pill i {
              color: #ef4444 !important;
              font-size: 11px !important;
            }

            /* Row 2: Full-Width Flipkart Search Bar */
            .header-search-container {
              display: block !important;
              width: 100% !important;
              max-width: 100% !important;
              flex: none !important;
              margin: 0 !important;
            }

            .header-search-form {
              display: flex !important;
              align-items: center !important;
              position: relative !important;
              width: 100% !important;
              background: #f8fafc !important;
              border: 1.5px solid #e2e8f0 !important;
              border-radius: 26px !important;
              box-shadow: 0 2px 6px rgba(0, 0, 0, 0.04) !important;
              transition: all 0.2s ease !important;
              box-sizing: border-box !important;
            }

            .header-search-form:focus-within {
              background: #ffffff !important;
              border-color: #ef4444 !important;
              box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.15) !important;
            }

            .header-search-icon {
              position: absolute !important;
              left: 14px !important;
              top: 50% !important;
              transform: translateY(-50%) !important;
              color: #64748b !important;
              font-size: 14px !important;
              pointer-events: none !important;
            }

            .header-search-input {
              width: 100% !important;
              background: transparent !important;
              border: none !important;
              outline: none !important;
              padding: 10px 88px 10px 38px !important;
              font-size: 13.5px !important;
              font-weight: 500 !important;
              color: #0f172a !important;
              box-sizing: border-box !important;
              line-height: 1.4 !important;
            }

            .header-search-input::placeholder {
              color: #94a3b8 !important;
              font-size: 13px !important;
            }

            .header-search-clear {
              position: absolute !important;
              right: 76px !important;
              top: 50% !important;
              transform: translateY(-50%) !important;
              background: none !important;
              border: none !important;
              color: #94a3b8 !important;
              font-size: 13px !important;
              cursor: pointer !important;
              padding: 4px !important;
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
            }

            .header-search-btn {
              position: absolute !important;
              right: 4px !important;
              top: 50% !important;
              transform: translateY(-50%) !important;
              background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%) !important;
              border: none !important;
              border-radius: 20px !important;
              color: #ffffff !important;
              padding: 6px 14px !important;
              font-size: 12px !important;
              font-weight: 700 !important;
              cursor: pointer !important;
              box-shadow: 0 2px 8px rgba(239, 68, 68, 0.3) !important;
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
            }

            /* ============================================================== */
            /* SECONDARY CATEGORY BAR & "ALL CATEGORIES" PILL                 */
            /* ============================================================== */
            .secondary-category-nav-wrapper {
              background: #ffffff !important;
              border-bottom: 1px solid #f1f5f9 !important;
              box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03) !important;
              position: sticky !important;
              top: 108px !important;
              z-index: 990 !important;
            }

            .secondary-category-nav-container {
              padding: 6px 12px !important;
              gap: 10px !important;
              height: auto !important;
              min-height: 44px !important;
            }

            /* All Categories Pill Button - Exact Web Aesthetic */
            .all-categories-pill-btn {
              background: #fff1f2 !important;
              color: #e11d48 !important;
              border: 1px solid rgba(225, 29, 72, 0.25) !important;
              border-radius: 8px !important;
              padding: 6px 12px !important;
              font-size: 13px !important;
              font-weight: 600 !important;
              box-shadow: none !important;
              display: inline-flex !important;
              align-items: center !important;
              gap: 8px !important;
              text-decoration: none !important;
              transition: all 0.18s ease !important;
            }

            .all-categories-pill-btn .pill-bars-icon,
            .all-categories-pill-btn .pill-chevron-icon,
            .all-categories-pill-btn .pill-label-text {
              color: #e11d48 !important;
              font-weight: 600 !important;
            }

            .all-categories-pill-btn.active,
            .all-categories-pill-btn.dropdown-open,
            .all-categories-pill-btn:active {
              background: #ffe4e6 !important;
              border-color: rgba(225, 29, 72, 0.4) !important;
              color: #be123c !important;
            }

            .all-categories-pill-btn.dropdown-open .pill-chevron-icon {
              transform: rotate(180deg) !important;
            }

            /* Product Enquiry File Upload Boxes */
            .product-file-upload-box {
              position: relative !important;
              cursor: pointer !important;
            }
            .product-file-upload-box input[type="file"] {
              position: absolute !important;
              top: 0 !important;
              left: 0 !important;
              width: 100% !important;
              height: 100% !important;
              opacity: 0 !important;
              cursor: pointer !important;
              z-index: 10 !important;
              display: block !important;
            }

            /* All Categories Pill Wrapper & Dropdown Menu */
            .all-categories-pill-wrapper {
              position: relative !important;
            }

            .all-categories-dropdown-menu {
              position: absolute !important;
              top: calc(100% + 6px) !important;
              left: 0 !important;
              width: calc(100vw - 28px) !important;
              max-width: 320px !important;
              max-height: 70vh !important;
              overflow-y: auto !important;
              background: #ffffff !important;
              border-radius: 16px !important;
              border: 1px solid #e2e8f0 !important;
              box-shadow: 0 16px 36px rgba(0, 0, 0, 0.16) !important;
              z-index: 99999 !important;
              padding: 10px 0 8px !important;
              -webkit-overflow-scrolling: touch !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-header {
              display: flex !important;
              align-items: center !important;
              justify-content: space-between !important;
              padding: 6px 16px 10px !important;
              border-bottom: 1px solid #f1f5f9 !important;
              font-size: 11px !important;
              font-weight: 800 !important;
              text-transform: uppercase !important;
              letter-spacing: 0.5px !important;
              color: #64748b !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-item {
              display: flex !important;
              align-items: center !important;
              justify-content: space-between !important;
              padding: 10px 16px !important;
              font-size: 13.5px !important;
              font-weight: 600 !important;
              color: #1e293b !important;
              text-decoration: none !important;
              border-bottom: 1px solid #f8fafc !important;
              transition: background 0.15s ease !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-item:active {
              background: #f1f5f9 !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-item .item-icon {
              margin-right: 10px !important;
              color: #ef4444 !important;
              font-size: 14px !important;
              width: 18px !important;
              text-align: center !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-arrow {
              font-size: 11px !important;
              color: #94a3b8 !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-footer {
              padding: 10px 16px 4px !important;
              border-top: 1px solid #f1f5f9 !important;
              margin-top: 4px !important;
            }

            .all-categories-dropdown-menu .cat-dropdown-footer a {
              color: #ef4444 !important;
              font-weight: 800 !important;
              font-size: 12.5px !important;
              text-decoration: none !important;
              display: flex !important;
              align-items: center !important;
              justify-content: space-between !important;
            }

            /* Horizontal Category Scroll Items */
            .secondary-category-items-scroll {
              display: flex !important;
              align-items: center !important;
              gap: 6px !important;
              overflow-x: auto !important;
              scrollbar-width: none !important;
              -webkit-overflow-scrolling: touch !important;
            }
            .secondary-category-items-scroll::-webkit-scrollbar {
              display: none !important;
            }

            .category-nav-link {
              background: #f8fafc !important;
              border: 1px solid #e2e8f0 !important;
              border-radius: 20px !important;
              padding: 5px 12px !important;
              font-size: 11.5px !important;
              font-weight: 700 !important;
              color: #475569 !important;
              white-space: nowrap !important;
              text-decoration: none !important;
              display: inline-flex !important;
              align-items: center !important;
              gap: 4px !important;
              box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03) !important;
              transition: all 0.15s ease !important;
            }

            .category-nav-link:active {
              transform: scale(0.96) !important;
            }

            .category-nav-link.active {
              background: #0f172a !important;
              color: #ffffff !important;
              border-color: #0f172a !important;
              font-weight: 800 !important;
              box-shadow: 0 2px 8px rgba(15, 23, 42, 0.25) !important;
            }

            .category-nav-link.hot-deals-link {
              background: #fff1f2 !important;
              color: #e11d48 !important;
              border-color: #fecdd3 !important;
              font-weight: 800 !important;
            }

            /* Explore Electronics Category Icons & Image Fallback Styling */
            .explore-category-icon-box {
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
              overflow: hidden !important;
              box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;
              border: 1px solid rgba(0, 0, 0, 0.04) !important;
            }

            .explore-category-fallback-icon {
              font-size: 26px !important;
              display: inline-flex !important;
              align-items: center !important;
              justify-content: center !important;
              line-height: 1 !important;
              transition: transform 0.2s ease !important;
            }

            .explore-category-item:active .explore-category-fallback-icon {
              transform: scale(1.15) !important;
            }
          }
        `;

      // 1b. Inject FontAwesome CDN for Crisp Vector Icons
      if (!document.getElementById('circuit-point-fa-cdn')) {
        var faLink = document.createElement('link');
        faLink.id = 'circuit-point-fa-cdn';
        faLink.rel = 'stylesheet';
        faLink.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
        document.head.appendChild(faLink);
      }

      // 2. Scroll to Top on Route Navigation
      function forceScrollToTop() {
        window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
        if (document.documentElement) document.documentElement.scrollTop = 0;
        if (document.body) document.body.scrollTop = 0;
      }

      if (!window.__circuitPointInjected) {
        window.__circuitPointInjected = true;

        var lastUrl = location.href;
        function handleUrlChange() {
          if (location.href !== lastUrl) {
            lastUrl = location.href;
            forceScrollToTop();
            setTimeout(forceScrollToTop, 50);
            setTimeout(forceScrollToTop, 150);
            setTimeout(forceScrollToTop, 300);
          }
        }

        var origPush = history.pushState;
        history.pushState = function() {
          origPush.apply(this, arguments);
          handleUrlChange();
        };

        var origReplace = history.replaceState;
        history.replaceState = function() {
          origReplace.apply(this, arguments);
          handleUrlChange();
        };

        window.addEventListener('popstate', function() {
          handleUrlChange();
        });

        // Fast tap listener for product cards
        document.addEventListener('click', function(e) {
          var target = e.target.closest('a');
          if (target && target.href && (target.href.includes('/product') || target.href.includes('/products'))) {
            setTimeout(forceScrollToTop, 20);
            setTimeout(forceScrollToTop, 100);
          }
        }, true);
      }

      // 3. Setup Popover Backdrop for User Profile Menu
      function setupUserModal() {
        var dropdown = document.querySelector('.user-dropdown-card');
        var userBackdrop = document.querySelector('.user-card-backdrop');

        if (dropdown) {
          if (!userBackdrop) {
            userBackdrop = document.createElement('div');
            userBackdrop.className = 'user-card-backdrop';
            document.body.appendChild(userBackdrop);
            userBackdrop.addEventListener('click', function(e) {
              e.stopPropagation();
              var btn = document.querySelector('.user-profile-btn');
              if (btn) btn.click();
            });
          }
          userBackdrop.classList.add('active');
        } else if (userBackdrop) {
          userBackdrop.classList.remove('active');
        }
      }

      // 4. Mobile Filter (handled natively by the website's React components)
      function setupMobileFilter() {}

      // 5. Setup Profile Page (handled natively by the website's React components)
      function setupProfilePage() {}

      // 6. Setup App Header (Flipkart-style: Remove Voxo, hide Home/Products, add delivery badge, style search bar)
      function setupAppHeader() {
        var voxoLogos = document.querySelectorAll('.brand-logo-img, .login-brand-logo-img, .footer-brand-tag');
        for (var i = 0; i < voxoLogos.length; i++) {
          voxoLogos[i].style.setProperty('display', 'none', 'important');
        }

        // Hide desktop nav links (Home, Products, Categories) and notification bell from top header
        var mainNav = document.querySelector('.main-nav');
        if (mainNav) {
          mainNav.style.setProperty('display', 'none', 'important');
        }
        var notifs = document.querySelectorAll('.notification-center-container, .header-notification-btn, .header-actions');
        for (var i = 0; i < notifs.length; i++) {
          notifs[i].style.setProperty('display', 'none', 'important');
        }

        // Add electronics chip emblem to brand section if not present
        var brandSec = document.querySelector('.brand-section');
        if (brandSec && !brandSec.querySelector('.va-brand-chip')) {
          var chip = document.createElement('span');
          chip.className = 'va-brand-chip';
          chip.innerHTML = '<i class="fas fa-microchip"></i>';
          brandSec.insertBefore(chip, brandSec.firstChild);
        }

        // Add Flipkart-style delivery badge on the right of the brand row
        var brandLeft = document.querySelector('.header-left-group');
        if (brandLeft && !brandLeft.querySelector('.header-delivery-pill')) {
          var deliveryPill = document.createElement('div');
          deliveryPill.className = 'header-delivery-pill';
          deliveryPill.innerHTML = '<i class="fas fa-bolt"></i> <span>Genuine Store</span>';
          brandLeft.appendChild(deliveryPill);
        }

        // Modern search input placeholder like Flipkart
        var searchInput = document.querySelector('.header-search-input');
        if (searchInput) {
          searchInput.placeholder = "Search components, sensors, Arduino, ICs...";
        }
      }

      // One-time cleanup for old hardcoded dummy session from previous builds (never touches real user logins)
      try {
        if (!localStorage.getItem('__cp_dummy_purged_v3')) {
          localStorage.setItem('__cp_dummy_purged_v3', '1');
          var t = localStorage.getItem('token');
          if (t && t.indexOf('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MTgzLCJlbWFpbCI6InNhYmFyaXNod2FyYW4xNzE4QGdtYWlsLmNvbSIsInBob25lX251bWJlciI6IjgwMTIxMDc2MjYiLCJ1c2VyX21haW5faWQi') === 0) {
            localStorage.removeItem('token');
            localStorage.removeItem('user');
            window.dispatchEvent(new Event('user-profile-updated'));
          }
        }
      } catch (e) {}

      if (!window.__cpImgFixInjected) {
        window.__cpImgFixInjected = true;
        window.addEventListener('error', function(e) {
          if (e.target && e.target.tagName === 'IMG') {
            var img = e.target;
            // Never replace captcha or auth modal images with product fallback
            if (img.closest && (img.closest('.auth-modal-card') || img.closest('.auth-modal-backdrop'))) {
              return;
            }
            if ((img.alt && img.alt.indexOf('Captcha') !== -1) || (img.src && img.src.indexOf('captcha') !== -1)) {
              return;
            }
            if (!img.dataset.fallbackDone) {
              img.dataset.fallbackDone = 'true';
              img.src = '/assets/images/electronics/product/1.jpg';
            }
          }
        }, true);
      }

      function getReactProps(el) {
        if (!el) return null;
        var keys = Object.keys(el);
        for (var i = 0; i < keys.length; i++) {
          if (keys[i].indexOf('__reactProps') === 0 || keys[i].indexOf('__reactEventHandlers') === 0) {
            return el[keys[i]];
          }
        }
        return null;
      }

      // Setup All Categories Pill Dropdown on Mobile Touch
      if (!window.__cpCatDropdownInjected) {
        window.__cpCatDropdownInjected = true;
        document.addEventListener('click', function(e) {
          var pillBtn = e.target.closest('.all-categories-pill-btn');
          if (pillBtn) {
            var wrapper = pillBtn.closest('.all-categories-pill-wrapper') || pillBtn.parentElement;
            if (wrapper) {
              e.preventDefault();
              e.stopPropagation();

              var menu = wrapper.querySelector('.all-categories-dropdown-menu');
              var props = getReactProps(wrapper) || getReactProps(pillBtn);

              if (!menu) {
                // Dropdown is currently closed: open it!
                if (props && typeof props.onMouseEnter === 'function') {
                  props.onMouseEnter();
                } else {
                  wrapper.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, cancelable: true }));
                  wrapper.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true, cancelable: true }));
                }
              } else {
                // Dropdown is open: close it!
                if (props && typeof props.onMouseLeave === 'function') {
                  props.onMouseLeave();
                } else {
                  wrapper.dispatchEvent(new MouseEvent('mouseleave', { bubbles: true, cancelable: true }));
                }
              }
            }
          } else if (!e.target.closest('.all-categories-pill-wrapper')) {
            // Clicked outside: close dropdown if open
            var openWrapper = document.querySelector('.all-categories-pill-wrapper');
            if (openWrapper && openWrapper.querySelector('.all-categories-dropdown-menu')) {
              var openProps = getReactProps(openWrapper);
              if (openProps && typeof openProps.onMouseLeave === 'function') {
                openProps.onMouseLeave();
              } else {
                openWrapper.dispatchEvent(new MouseEvent('mouseleave', { bubbles: true, cancelable: true }));
              }
            }
          }
        }, true);
      }

      // 7. Auto-resume Wishlist & Add-to-Cart after Guest Login (Flipkart style)
      function setupAuthResumeHandler() {
        if (window.__cpAuthResumeInjected) return;
        window.__cpAuthResumeInjected = true;

        var pendingAction = null;
        var lastClickedBtn = null;

        // Capture auth-required events
        window.addEventListener('auth-required', function(e) {
          if (e && e.detail) {
            pendingAction = e.detail;
            try {
              sessionStorage.setItem('__cp_pending_action', JSON.stringify(e.detail));
            } catch(err) {}

            var product = e.detail.product;
            if (e.detail.action === 'wishlist' && product) {
              try {
                var cur = localStorage.getItem('wishlist_guest');
                var list = cur ? JSON.parse(cur) : [];
                var pid = String(product.product_id || product.id);
                if (!list.some(function(item) { return String(item.product_id || item.id) === pid; })) {
                  list.unshift(product);
                  localStorage.setItem('wishlist_guest', JSON.stringify(list));
                }
              } catch(err) {}
            } else if (e.detail.action === 'cart' && product) {
              try {
                sessionStorage.setItem('__cp_pending_cart', JSON.stringify({
                  product: product,
                  quantity: e.detail.quantity || 1
                }));
              } catch(err) {}
            }
          }
        });

        // Capture user taps on wishlist/cart buttons when not logged in
        document.addEventListener('click', function(e) {
          var token = localStorage.getItem('token');
          if (token) return; // Already logged in

          var wishlistBtn = e.target.closest('.btn-wishlist-heart, .btn-wishlist-circle');
          var cartBtn = e.target.closest('.btn-add-cart, .btn-primary-add-cart');

          if (wishlistBtn) {
            lastClickedBtn = wishlistBtn;
            var card = wishlistBtn.closest('.product-card-modern, .product-detail-container, .product-details-wrap') || document;
            var link = card.querySelector('a[href*="/products/"]');
            var pid = null;
            if (link && link.href) {
              var parts = link.href.split('/products/');
              if (parts.length > 1) {
                pid = parts[1].split('?')[0].split('#')[0];
                if (pid && pid.endsWith('/')) pid = pid.slice(0, -1);
              }
            }
            if (!pid && window.location.pathname.indexOf('/products/') !== -1) {
              var parts = window.location.pathname.split('/products/');
              if (parts.length > 1) {
                pid = parts[1].split('?')[0].split('#')[0];
                if (pid && pid.endsWith('/')) pid = pid.slice(0, -1);
              }
            }
            if (!pendingAction || pendingAction.action !== 'wishlist') {
              pendingAction = {
                action: 'wishlist',
                productId: pid,
                btnSelector: wishlistBtn.className
              };
            }
            try {
              sessionStorage.setItem('__cp_pending_action', JSON.stringify(pendingAction));
            } catch(err) {}
          } else if (cartBtn) {
            lastClickedBtn = cartBtn;
            var card = cartBtn.closest('.product-card-modern, .product-detail-container, .product-details-wrap') || document;
            var link = card.querySelector('a[href*="/products/"]');
            var pid = null;
            if (link && link.href) {
              var parts = link.href.split('/products/');
              if (parts.length > 1) {
                pid = parts[1].split('?')[0].split('#')[0];
                if (pid && pid.endsWith('/')) pid = pid.slice(0, -1);
              }
            }
            if (!pid && window.location.pathname.indexOf('/products/') !== -1) {
              var parts = window.location.pathname.split('/products/');
              if (parts.length > 1) {
                pid = parts[1].split('?')[0].split('#')[0];
                if (pid && pid.endsWith('/')) pid = pid.slice(0, -1);
              }
            }
            if (!pendingAction || pendingAction.action !== 'cart') {
              pendingAction = {
                action: 'cart',
                productId: pid,
                quantity: 1,
                btnSelector: cartBtn.className
              };
            }
            try {
              sessionStorage.setItem('__cp_pending_action', JSON.stringify(pendingAction));
            } catch(err) {}
          }
        }, true);

        function executePendingAction() {
          var stored = null;
          try {
            var raw = sessionStorage.getItem('__cp_pending_action');
            if (raw) stored = JSON.parse(raw);
          } catch(err) {}

          var actionData = pendingAction || stored;
          if (!actionData) return;

          var token = localStorage.getItem('token');
          if (!token) return; // Not yet logged in

          // Clear pending action so it runs only once
          pendingAction = null;
          try {
            sessionStorage.removeItem('__cp_pending_action');
          } catch(err) {}

          var action = actionData.action;
          var product = actionData.product;
          var productId = (product && (product.id || product.product_id)) || actionData.productId;

          setTimeout(function() {
            var userRaw = localStorage.getItem('user');
            var userId = '';
            var virtualId = '';
            var userObj = {};
            if (userRaw) {
              try {
                userObj = JSON.parse(userRaw);
                userId = userObj.user_main_id || userObj.userId || userObj.user_id || userObj.id || userObj.virtual_id || userObj.email || '';
                virtualId = userObj.virtual_id || userObj.virtualId || userObj.vid || '';
              } catch(e) {}
            }

            var pid = String(productId || (product && (product.product_id || product.id)) || '');

            if (action === 'wishlist') {
              var wishPayload = {
                product_id: pid,
                id: pid,
                product_name: (product && (product.product_name || product.name)) || "Product",
                name: (product && (product.product_name || product.name)) || "Product",
                mrp: (product && (product.mrp || product.original_price || product.price)) || 0,
                price: (product && (product.selling_price || product.price || product.mrp)) || 0,
                image_url: (product && (product.image_url || product.base_image)) || "/assets/images/fashion/product/front/1.jpg",
                brands: (product && (product.brands || product.brand)) || "Imported",
                categories: (product && (product.categories || product.primary_category)) || "Electronics",
                stock_quantity: 50,
                status: "active",
                created_at: new Date().toISOString()
              };

              // 1. Write to all possible wishlist localStorage keys
              var keys = [
                'wishlist_' + userId,
                'wishlist_' + virtualId,
                'wishlist_' + (userObj.id || ''),
                'wishlist_' + (userObj.email || ''),
                'wishlist_guest'
              ];
              keys.forEach(function(k) {
                if (!k || k === 'wishlist_') return;
                try {
                  var cur = localStorage.getItem(k);
                  var list = cur ? JSON.parse(cur) : [];
                  if (!list.some(function(item) { return String(item.product_id || item.id) === pid; })) {
                    list.unshift(wishPayload);
                    localStorage.setItem(k, JSON.stringify(list));
                  }
                } catch(e) {}
              });

              // 2. Call backend Wishlist API with token
              fetch('https://shop.circuitpointcare.com/api/wishlist', {
                method: 'POST',
                headers: {
                  'Authorization': 'Bearer ' + token,
                  'x-user-id': String(userId || virtualId),
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify(wishPayload)
              }).then(function() {
                window.dispatchEvent(new Event('storage'));
              }).catch(function() {});

              // 3. Turn matching hearts RED on screen immediately
              var hearts = document.querySelectorAll('.btn-wishlist-heart, .btn-wishlist-circle');
              hearts.forEach(function(h) {
                var card = h.closest('.product-card-modern, .product-detail-container, .product-details-wrap') || document;
                if (card === document || (card.innerHTML && card.innerHTML.indexOf('/products/' + pid) !== -1) || window.location.pathname.indexOf('/products/' + pid) !== -1) {
                  h.classList.add('wishlisted');
                  var icon = h.querySelector('i');
                  if (icon) {
                    icon.className = 'fas fa-heart text-danger';
                    icon.style.color = '#e11d48';
                  }
                }
              });

              // 4. Try clicking the button as well to update React state
              if (lastClickedBtn && document.body.contains(lastClickedBtn)) {
                try { lastClickedBtn.click(); } catch(e) {}
              }

              // 5. Show attractive toast
              var toast = document.createElement('div');
              toast.className = 'cp-auto-toast';
              toast.innerHTML = '<i class="fas fa-heart" style="color:#e11d48;margin-right:8px;font-size:16px;"></i> Saved to your Wishlist!';
              toast.style.cssText = 'position:fixed;bottom:85px;left:50%;transform:translateX(-50%);background:#0f172a;color:#ffffff;padding:12px 22px;border-radius:30px;font-size:13px;font-weight:700;z-index:999999;box-shadow:0 12px 30px rgba(0,0,0,0.35);display:flex;align-items:center;';
              document.body.appendChild(toast);
              setTimeout(function() {
                toast.style.opacity = '0';
                toast.style.transition = 'opacity 0.4s ease';
                setTimeout(function() { toast.remove(); }, 400);
              }, 2500);

              window.dispatchEvent(new Event('storage'));
            } else if (action === 'cart') {
              var qty = (actionData && actionData.quantity) || 1;
              var cartPayload = {
                productId: pid,
                id: pid,
                product_name: (product && (product.product_name || product.name)) || "Product",
                name: (product && (product.product_name || product.name)) || "Product",
                mrp: (product && (product.mrp || product.price)) || 0,
                price: (product && (product.price || product.mrp)) || 0,
                image_url: (product && (product.image_url || product.base_image)) || "/assets/images/fashion/product/front/1.jpg",
                brands: (product && (product.brands || product.brand)) || "Imported",
                categories: (product && (product.categories || product.primary_category)) || "Electronics",
                quantity: qty,
                virtual_id: virtualId
              };

              // 1. Write to cart localStorage keys
              var cartKeys = [
                'cart_' + virtualId,
                'cart_' + userId,
                'cart_' + (userObj.id || ''),
                'cart_guest'
              ];
              cartKeys.forEach(function(k) {
                if (!k || k === 'cart_') return;
                try {
                  var cur = localStorage.getItem(k);
                  var list = cur ? JSON.parse(cur) : [];
                  var existing = list.find(function(item) { return String(item.id || item.productId) === pid; });
                  if (existing) {
                    existing.quantity = (existing.quantity || 1) + qty;
                  } else {
                    list.push(cartPayload);
                  }
                  localStorage.setItem(k, JSON.stringify(list));
                } catch(e) {}
              });

              // 2. Call backend Cart API
              fetch('https://shop.circuitpointcare.com/api/cart', {
                method: 'POST',
                headers: {
                  'Authorization': 'Bearer ' + token,
                  'x-user-id': String(userId || virtualId),
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify(cartPayload)
              }).then(function() {
                window.dispatchEvent(new Event('storage'));
              }).catch(function() {});

              // 3. Try clicking the button
              if (lastClickedBtn && document.body.contains(lastClickedBtn)) {
                try { lastClickedBtn.click(); } catch(e) {}
              }

              // 4. Show attractive toast
              var toast = document.createElement('div');
              toast.className = 'cp-auto-toast';
              toast.innerHTML = '<i class="fas fa-check-circle" style="color:#10b981;margin-right:8px;font-size:16px;"></i> Added to your Cart!';
              toast.style.cssText = 'position:fixed;bottom:85px;left:50%;transform:translateX(-50%);background:#0f172a;color:#ffffff;padding:12px 22px;border-radius:30px;font-size:13px;font-weight:700;z-index:999999;box-shadow:0 12px 30px rgba(0,0,0,0.35);display:flex;align-items:center;';
              document.body.appendChild(toast);
              setTimeout(function() {
                toast.style.opacity = '0';
                toast.style.transition = 'opacity 0.4s ease';
                setTimeout(function() { toast.remove(); }, 400);
              }, 2500);

              window.dispatchEvent(new Event('storage'));
            }

            lastClickedBtn = null;
          }, 350);
        }

        window.addEventListener('user-profile-updated', executePendingAction);

        var lastKnownToken = localStorage.getItem('token');
        setInterval(function() {
          var curToken = localStorage.getItem('token');
          if (curToken && !lastKnownToken) {
            lastKnownToken = curToken;
            executePendingAction();
          } else {
            lastKnownToken = curToken;
          }
        }, 500);
      }

      setupUserModal();
      setupMobileFilter();
      setupProfilePage();
      setupAppHeader();
      setupAuthResumeHandler();
      if (!window.__circuitPointInterval) {
        window.__circuitPointInterval = setInterval(function() {
          setupUserModal();
          setupMobileFilter();
          setupProfilePage();
          setupAppHeader();
          setupAuthResumeHandler();
        }, 500);
      }
    })();
    ''';

    _controller.runJavaScript(js);
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial app link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link stream error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');
    if (uri.host == 'shop.circuitpointcare.com' ||
        uri.host == 'circuitpoint.circuitpointcare.com' ||
        uri.host == 'rtest.epriceoffer.com') {
      setState(() {
        _hasError = false;
      });
      _controller.loadRequest(uri);
    }
  }

  void _reloadPage() {
    setState(() {
      _hasError = false;
    });
    _controller.reload();
  }

  void _updateBottomNavIndex(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? '';

    if (path == '' || path == '/' || path == '/home') {
      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      }
      return;
    }

    if (path.contains('categories')) {
      if (_currentIndex != 1) {
        setState(() => _currentIndex = 1);
      }
      return;
    }

    if (path.contains('product')) {
      if (_currentIndex != 2) {
        setState(() => _currentIndex = 2);
      }
      return;
    }

    if (path.contains('wishlist')) {
      if (_currentIndex != 3) {
        setState(() => _currentIndex = 3);
      }
      return;
    }

    if (path.contains('cart')) {
      if (_currentIndex != 4) {
        setState(() => _currentIndex = 4);
      }
      return;
    }

    if (path.contains('profile') ||
        path.contains('login') ||
        path.contains('account')) {
      if (_currentIndex != 5) {
        setState(() => _currentIndex = 5);
      }
      return;
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

    final item = _navItems[index];

    // Products Trigger
    if (item.url == '/products') {
      _controller.runJavaScript('''
        var btn = document.querySelector("a[href='/products'], a[href*='products']");
        if (btn) {
          btn.click();
        } else {
          var a = document.createElement('a');
          a.href = '/products';
          document.body.appendChild(a);
          var event = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
          a.dispatchEvent(event);
          a.remove();
        }
      ''');
      return;
    }

    // Orders Drawer Trigger (opens My Orders & Tracking drawer like web)
    if (item.url == '/orders') {
      _controller.runJavaScript('''
        var btn = document.querySelector(".header-orders-btn");
        if (btn) {
          btn.click();
        } else {
          window.dispatchEvent(new Event("open-orders-modal"));
        }
      ''');
      return;
    }

    // Wishlist Trigger
    if (item.url == '/wishlist') {
      _controller.runJavaScript('''
        var btn = document.querySelector(".header-wishlist-btn");
        if (btn) {
          btn.click();
        } else {
          var a = document.createElement('a');
          a.href = '/wishlist';
          document.body.appendChild(a);
          var event = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
          a.dispatchEvent(event);
          a.remove();
        }
      ''');
      return;
    }

    // Cart Drawer Trigger
    if (item.url == '/cart') {
      _controller.runJavaScript('''
        var btn = document.querySelector(".header-cart-btn");
        if (btn) {
          btn.click();
        } else {
          var a = document.createElement('a');
          a.href = '/cart';
          document.body.appendChild(a);
          var event = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
          a.dispatchEvent(event);
          a.remove();
        }
      ''');
      return;
    }

    // My Account Trigger -> Shows / Toggles Website's Exact My Account Popover Card
    if (item.url == '/profile') {
      _controller.runJavaScript(r'''
        (function() {
          var existingMenu = document.getElementById('mobile-my-account-popup');
          var existingBackdrop = document.getElementById('mobile-my-account-backdrop');

          if (existingMenu) {
            existingMenu.classList.remove('active');
            if (existingBackdrop) existingBackdrop.classList.remove('active');
            setTimeout(function() {
              if (existingMenu && existingMenu.parentNode) existingMenu.parentNode.removeChild(existingMenu);
              if (existingBackdrop && existingBackdrop.parentNode) existingBackdrop.parentNode.removeChild(existingBackdrop);
            }, 180);
            return;
          }

          // Ensure FontAwesome CDN is present for vector icons
          if (!document.getElementById('circuit-point-fa-cdn')) {
            var fa = document.createElement('link');
            fa.id = 'circuit-point-fa-cdn';
            fa.rel = 'stylesheet';
            fa.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
            document.head.appendChild(fa);
          }

          // Ensure styles are injected
          if (!document.getElementById('mobile-account-popup-styles')) {
            var st = document.createElement('style');
            st.id = 'mobile-account-popup-styles';
            st.textContent = `
              .mobile-my-account-backdrop {
                position: fixed !important;
                inset: 0 !important;
                background: rgba(0, 0, 0, 0.28) !important;
                z-index: 999998 !important;
                opacity: 0;
                transition: opacity 0.15s ease-out !important;
              }
              .mobile-my-account-backdrop.active {
                opacity: 1 !important;
              }
              .mobile-exact-account-card {
                position: fixed !important;
                bottom: 80px !important;
                right: 12px !important;
                width: 245px !important;
                max-width: calc(100vw - 24px) !important;
                background: #ffffff !important;
                border: 1px solid #e2e8f0 !important;
                border-radius: 14px !important;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15), 0 3px 8px rgba(0, 0, 0, 0.06) !important;
                z-index: 999999 !important;
                padding: 8px 6px !important;
                box-sizing: border-box !important;
                opacity: 0;
                transform: translateY(8px) scale(0.96);
                transition: opacity 0.16s ease-out, transform 0.16s cubic-bezier(0.16, 1, 0.3, 1) !important;
                transform-origin: bottom right !important;
              }
              .mobile-exact-account-card.active {
                opacity: 1 !important;
                transform: translateY(0) scale(1) !important;
              }
              .mobile-exact-account-card .user-dropdown-header {
                background: transparent !important;
                border-bottom: 1px solid #f1f5f9 !important;
                border-radius: 0 !important;
                padding: 6px 10px 8px 10px !important;
                margin-bottom: 4px !important;
              }
              .mobile-exact-account-card .user-dropdown-name {
                font-size: 14.5px !important;
                font-weight: 700 !important;
                color: #0f172a !important;
                letter-spacing: -0.2px !important;
                margin: 0 !important;
              }
              .mobile-exact-account-card .user-dropdown-email {
                font-size: 12px !important;
                font-weight: 500 !important;
                color: #64748b !important;
                margin-top: 2px !important;
                word-break: break-all !important;
                white-space: normal !important;
              }
              .mobile-exact-account-card .user-dropdown-item {
                font-size: 13.5px !important;
                font-weight: 600 !important;
                padding: 8.5px 12px !important;
                border-radius: 8px !important;
                display: flex !important;
                align-items: center !important;
                gap: 10px !important;
                color: #1e293b !important;
                text-decoration: none !important;
                cursor: pointer !important;
                margin: 1px 0 !important;
                width: 100% !important;
                box-sizing: border-box !important;
                transition: background 0.12s ease !important;
                user-select: none !important;
              }
              .mobile-exact-account-card .user-dropdown-item:active {
                background: #f1f5f9 !important;
              }
              .mobile-exact-account-card .user-dropdown-item i {
                font-size: 14px !important;
                width: 18px !important;
                text-align: center !important;
              }
              .mobile-exact-account-card .user-dropdown-item.logout {
                color: #dc2626 !important;
              }
              .mobile-exact-account-card .user-dropdown-item.logout i {
                color: #dc2626 !important;
              }
            `;
            document.head.appendChild(st);
          }

          var user = null;
          try {
            var rawUser = localStorage.getItem("user");
            if (rawUser) user = JSON.parse(rawUser);
          } catch(e) {}
          var token = localStorage.getItem("token");
          var isLoggedIn = Boolean(token || (user && (user.id || user.email || user.name)));

          var title = "My Account";
          var subtitle = "My Account";
          if (user) {
            title = user.name || user.full_name || (user.email ? user.email.split('@')[0] : "My Account");
            subtitle = user.email || (isLoggedIn ? "customer@srivagroups.in" : "My Account");
          }

          var cartBadge = document.querySelector('.header-cart-badge');
          var cartCount = cartBadge ? cartBadge.textContent.trim() : '0';
          var wishBadge = document.querySelector('.header-wishlist-badge');
          var wishCount = wishBadge ? wishBadge.textContent.trim() : '0';
          var ordersBadge = document.querySelector('.header-orders-badge');
          var ordersCount = ordersBadge ? ordersBadge.textContent.trim() : '';

          var backdrop = document.createElement('div');
          backdrop.id = 'mobile-my-account-backdrop';
          backdrop.className = 'mobile-my-account-backdrop';
          document.body.appendChild(backdrop);

          var card = document.createElement('div');
          card.id = 'mobile-my-account-popup';
          card.className = 'mobile-exact-account-card';

          card.innerHTML = `
            <div class="user-dropdown-header">
              <div class="user-dropdown-name">${title}</div>
              <div class="user-dropdown-email">${subtitle}</div>
            </div>
            <div class="user-dropdown-item" id="cp-item-home">
              <i class="fas fa-home" style="width: 16px; color: #475569;"></i>
              <span>Home</span>
            </div>
            <div class="user-dropdown-item" id="cp-item-profile">
              <i class="fas fa-user-circle" style="width: 16px; color: #475569;"></i>
              <span>My Profile</span>
            </div>
            <div class="user-dropdown-item" id="cp-item-address">
              <i class="fas fa-map-marker-alt" style="width: 16px; color: #e11d48;"></i>
              <span>Add Address</span>
            </div>
            <div class="user-dropdown-item" id="cp-item-wishlist">
              <i class="fas fa-heart" style="width: 16px; color: #e11d48;"></i>
              <span>My Wishlist (${wishCount})</span>
            </div>
            <div class="user-dropdown-item" id="cp-item-cart">
              <i class="fas fa-shopping-cart" style="width: 16px; color: #475569;"></i>
              <span>My Cart (${cartCount})</span>
            </div>
            <div class="user-dropdown-item" id="cp-item-orders">
              <i class="fas fa-truck-fast" style="width: 16px; color: #e11d48;"></i>
              <span>My Orders &amp; Tracking ${ordersCount ? '(' + ordersCount + ')' : ''}</span>
            </div>
            <div style="height: 1px; background: #f1f5f9; margin: 4px 0;"></div>
            ${isLoggedIn ? `
              <div class="user-dropdown-item logout" id="cp-item-logout">
                <i class="fas fa-sign-out-alt" style="width: 16px; color: #dc2626;"></i>
                <span>Logout</span>
              </div>
            ` : `
              <div class="user-dropdown-item" id="cp-item-signin">
                <i class="fas fa-sign-in-alt" style="width: 16px; color: #e11d48;"></i>
                <span>Sign In</span>
              </div>
              <div class="user-dropdown-item" id="cp-item-register">
                <i class="fas fa-user-plus" style="width: 16px; color: #e11d48;"></i>
                <span>New User? Register</span>
              </div>
            `}
          `;

          document.body.appendChild(card);

          function closeMenu() {
            card.classList.remove('active');
            backdrop.classList.remove('active');
            setTimeout(function() {
              if (card && card.parentNode) card.parentNode.removeChild(card);
              if (backdrop && backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
            }, 180);
          }

          backdrop.onclick = closeMenu;

          requestAnimationFrame(function() {
            backdrop.classList.add('active');
            card.classList.add('active');
          });

          document.getElementById('cp-item-home').onclick = function() {
            closeMenu();
            var a = document.querySelector("a[href='/home'], a[href='/']");
            if (a) a.click(); else window.location.href = '/home';
          };

          document.getElementById('cp-item-profile').onclick = function() {
            closeMenu();
            if (isLoggedIn) {
              var a = document.querySelector("a[href='/profile'], a[href*='profile']");
              if (a) a.click(); else window.location.href = '/profile';
            } else {
              window.dispatchEvent(new CustomEvent("auth-required", {
                detail: { force: true, action: "profile", viewMode: "login", returnUrl: "/profile", source: "navbar" }
              }));
            }
          };

          document.getElementById('cp-item-address').onclick = function() {
            closeMenu();
            window.dispatchEvent(new CustomEvent("open-address-modal"));
          };

          document.getElementById('cp-item-wishlist').onclick = function() {
            closeMenu();
            var a = document.querySelector("a[href='/wishlist'], .header-wishlist-btn");
            if (a) a.click(); else window.location.href = '/wishlist';
          };

          document.getElementById('cp-item-cart').onclick = function() {
            closeMenu();
            var btn = document.querySelector(".header-cart-btn");
            if (btn) btn.click(); else window.location.href = '/cart';
          };

          document.getElementById('cp-item-orders').onclick = function() {
            closeMenu();
            var btn = document.querySelector(".header-orders-btn");
            if (btn) btn.click(); else window.dispatchEvent(new Event("open-orders-modal"));
          };

          var signinBtn = document.getElementById('cp-item-signin');
          if (signinBtn) {
            signinBtn.onclick = function() {
              closeMenu();
              window.dispatchEvent(new CustomEvent("auth-required", {
                detail: { force: true, action: "login", viewMode: "login", returnUrl: location.pathname, source: "navbar" }
              }));
            };
          }

          var regBtn = document.getElementById('cp-item-register');
          if (regBtn) {
            regBtn.onclick = function() {
              closeMenu();
              window.dispatchEvent(new CustomEvent("auth-required", {
                detail: { force: true, action: "register", viewMode: "register", returnUrl: location.pathname, source: "navbar" }
              }));
            };
          }

          var logoutBtn = document.getElementById('cp-item-logout');
          if (logoutBtn) {
            logoutBtn.onclick = function() {
              closeMenu();
              localStorage.removeItem("token");
              localStorage.removeItem("user");
              window.dispatchEvent(new Event("user-profile-updated"));
              window.dispatchEvent(new Event("orders-updated"));
              window.location.href = '/home';
            };
          }
        })();
      ''');
      return;
    }

    // Default Navigation (Home, Categories)
    _controller.runJavaScript('''
      var btn = document.querySelector("${item.selector}");
      if (btn) {
        btn.click();
      } else {
        var a = document.createElement('a');
        a.href = '${item.url}';
        document.body.appendChild(a);
        var event = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
        a.dispatchEvent(event);
        a.remove();
      }
    ''');
  }

  Future<void> _handleBackPress() async {
    // 0. If User Profile dropdown menu is open, close it on back press
    try {
      final isDropdownOpen = await _controller.runJavaScriptReturningResult(
        'Boolean(document.getElementById("mobile-my-account-popup") || document.querySelector(".user-dropdown-card"))',
      );
      if (isDropdownOpen == true || isDropdownOpen.toString() == 'true') {
        await _controller.runJavaScript('''
          var b = document.getElementById("mobile-my-account-backdrop");
          if (b) {
            b.click();
          } else {
            var profileBtn = document.querySelector(".user-profile-btn");
            if (profileBtn) profileBtn.click();
          }
        ''');
        return;
      }
    } catch (_) {}

    // 1. If Orders drawer is open, back button closes the orders drawer
    try {
      final isOrdersOpen = await _controller.runJavaScriptReturningResult(
        'Boolean(document.querySelector(".orders-drawer-overlay"))',
      );
      if (isOrdersOpen == true || isOrdersOpen.toString() == 'true') {
        await _controller.runJavaScript('''
          var closeBtn = document.querySelector(".orders-drawer-close");
          if (closeBtn) {
            closeBtn.click();
          } else {
            var overlay = document.querySelector(".orders-drawer-overlay");
            if (overlay) overlay.click();
          }
        ''');
        return;
      }
    } catch (_) {}

    // 2. If Cart drawer is open, back button closes the cart drawer
    try {
      final isCartOpen = await _controller.runJavaScriptReturningResult(
        'Boolean(document.querySelector(".cart-drawer-overlay"))',
      );
      if (isCartOpen == true || isCartOpen.toString() == 'true') {
        await _controller.runJavaScript('''
          var closeBtn = document.querySelector(".cart-drawer-close");
          if (closeBtn) {
            closeBtn.click();
          } else {
            var overlay = document.querySelector(".cart-drawer-overlay");
            if (overlay) overlay.click();
          }
        ''');
        return;
      }
    } catch (_) {}

    // 3. If mobile filter drawer is open, back button closes the filter drawer
    try {
      final isDrawerOpen = await _controller.runJavaScriptReturningResult(
        'Boolean(document.querySelector(".products-filter-sidebar-col.mobile-open"))',
      );
      if (isDrawerOpen == true || isDrawerOpen.toString() == 'true') {
        await _controller.runJavaScript('''
          var filterBtn = document.querySelector(".products-mobile-filter-btn, .filter-sidebar-mobile-close-btn");
          if (filterBtn) {
            filterBtn.click();
          }
        ''');
        return;
      }
    } catch (_) {}

    // 4. Web history back
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return;
    }

    // 5. Double back press to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 60,
                color: Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Problem',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reloadPage,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBottomBar() {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final isSelected = _currentIndex == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onBottomNavTapped(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 10 : 4,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE53935).withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected
                          ? const Color(0xFFE53935)
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFFE53935)
                          : Colors.grey.shade700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 68),
                child: RefreshIndicator(
                  color: const Color(0xFFE53935),
                  onRefresh: () async {
                    _reloadPage();
                  },
                  child: WebViewWidget(controller: _controller),
                ),
              ),
              if (_hasError) _buildErrorView(),
              if (_loadingProgress < 1.0 && !_hasError)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE53935),
                    ),
                    minHeight: 3,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildFloatingBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
