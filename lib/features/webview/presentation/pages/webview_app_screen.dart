import 'dart:async';
import 'dart:convert';
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

  final String _baseUrl = 'https://circuitpoint.circuitpointcare.com';

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
      label: 'Orders',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping_rounded,
      url: '/orders',
      selector: ".header-orders-btn",
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
      label: 'Account',
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
          debugPrint('WebView Main Frame Error: ${error.description} (code: ${error.errorCode})');
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
            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!launched) {
              await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            }
          } catch (e) {
            debugPrint('Could not launch external URL: ${request.url}, error: $e');
          }
          return NavigationDecision.prevent;
        }

        return NavigationDecision.navigate;
      },
    );

    if (navigationDelegate.platform is AndroidNavigationDelegate) {
      final androidNav = navigationDelegate.platform as AndroidNavigationDelegate;
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
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        try {
          FileType fileType = FileType.any;
          List<String>? allowedExtensions;

          final accepts = params.acceptTypes;
          final bool acceptsImages = accepts.any((t) => t.toLowerCase().contains('image'));
          final bool acceptsPdf = accepts.any((t) => t.toLowerCase().contains('pdf'));

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
          /* Crisp Solid Translucent Backdrop (No blur filter to prevent blurry fonts) */
          .user-card-backdrop {
            display: none;
            position: fixed !important;
            inset: 0 !important;
            background: rgba(15, 23, 42, 0.65) !important;
            z-index: 99998 !important;
            animation: backdropFadeIn 0.2s ease-out !important;
          }
          .user-card-backdrop.active {
            display: block !important;
          }
          @keyframes backdropFadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }

          /* Razor-Sharp Center Account Modal */
          .user-dropdown-card {
            position: fixed !important;
            top: 0 !important;
            bottom: 0 !important;
            left: 0 !important;
            right: 0 !important;
            margin: auto !important;
            height: fit-content !important;
            max-height: 82vh !important;
            width: calc(100% - 36px) !important;
            max-width: 350px !important;
            overflow-y: auto !important;
            background: #ffffff !important;
            border-radius: 26px !important;
            box-shadow: 0 25px 65px rgba(0, 0, 0, 0.4) !important;
            z-index: 99999 !important;
            padding: 16px 14px !important;
            border: 1px solid #e2e8f0 !important;
            box-sizing: border-box !important;
            -webkit-font-smoothing: antialiased !important;
            text-rendering: optimizeLegibility !important;
          }

          .user-dropdown-header {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%) !important;
            border-radius: 18px !important;
            padding: 14px 16px !important;
            margin-bottom: 10px !important;
            position: relative !important;
          }

          .user-dropdown-name {
            font-size: 16px !important;
            font-weight: 800 !important;
            color: #ffffff !important;
            letter-spacing: -0.2px !important;
          }

          .user-dropdown-email {
            font-size: 12.5px !important;
            color: #f87171 !important;
            font-weight: 600 !important;
            word-break: break-all !important;
            white-space: normal !important;
            margin-top: 2px !important;
          }

          .user-dropdown-close-btn {
            position: absolute !important;
            top: 12px !important;
            right: 12px !important;
            width: 28px !important;
            height: 28px !important;
            border-radius: 50% !important;
            background: rgba(255, 255, 255, 0.15) !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            font-size: 12px !important;
            font-weight: bold !important;
            color: #ffffff !important;
            cursor: pointer !important;
          }

          .user-dropdown-item {
            font-size: 14px !important;
            font-weight: 600 !important;
            padding: 10px 14px !important;
            border-radius: 12px !important;
            display: flex !important;
            align-items: center !important;
            gap: 12px !important;
            color: #334155 !important;
            text-decoration: none !important;
            cursor: pointer !important;
            margin: 2px 0 !important;
            transition: all 0.15s ease !important;
          }

          .user-dropdown-item:active {
            background: #f1f5f9 !important;
            transform: scale(0.98) !important;
          }

          .user-dropdown-item i {
            font-size: 16px !important;
            width: 22px !important;
            text-align: center !important;
            color: #E53935 !important;
          }

          .user-dropdown-item.logout {
            color: #dc2626 !important;
            background: #fef2f2 !important;
            margin-top: 6px !important;
          }
          .user-dropdown-item.logout i {
            color: #dc2626 !important;
          }

          @media (max-width: 991px) {
            /* Products layout: Products show first */
            .products-layout-wrapper {
              display: flex !important;
              flex-direction: column !important;
              overflow: visible !important;
            }
            .products-catalog-main-content {
              width: 100% !important;
              order: 1 !important;
              max-width: 100% !important;
            }

            /* Filter sidebar turned into a Mobile Side Drawer */
            .products-filter-sidebar-col {
              position: fixed !important;
              top: 0 !important;
              left: 0 !important;
              bottom: 0 !important;
              width: 85% !important;
              max-width: 320px !important;
              height: 100vh !important;
              height: 100dvh !important;
              background: #ffffff !important;
              z-index: 99999 !important;
              box-shadow: 4px 0 25px rgba(0, 0, 0, 0.25) !important;
              transform: translateX(-105%) !important;
              transition: transform 0.28s cubic-bezier(0.16, 1, 0.3, 1) !important;
              overflow-y: auto !important;
              -webkit-overflow-scrolling: touch !important;
              padding: 20px 16px !important;
              box-sizing: border-box !important;
              display: block !important;
            }
            .products-filter-sidebar-col.mobile-drawer-open {
              transform: translateX(0) !important;
            }
            .filter-sidebar-card {
              border: none !important;
              box-shadow: none !important;
              padding: 0 !important;
              margin: 0 !important;
            }

            /* Clean dark backdrop when drawer is open (no blur) */
            .mobile-filter-backdrop {
              display: none;
              position: fixed !important;
              top: 0 !important;
              left: 0 !important;
              right: 0 !important;
              bottom: 0 !important;
              background: rgba(0, 0, 0, 0.6) !important;
              z-index: 99998 !important;
            }
            .mobile-filter-backdrop.active {
              display: block !important;
            }

            /* Sleek Filter Trigger Button on Toolbar */
            .mobile-filter-toggle-btn {
              display: inline-flex !important;
              align-items: center !important;
              gap: 6px !important;
              background: #ffffff !important;
              border: 1.5px solid #E53935 !important;
              color: #E53935 !important;
              font-weight: 700 !important;
              font-size: 13px !important;
              padding: 6px 14px !important;
              border-radius: 20px !important;
              cursor: pointer !important;
              box-shadow: 0 2px 6px rgba(229, 57, 53, 0.12) !important;
              margin-right: auto !important;
            }
            .mobile-filter-toggle-btn:active {
              background: #E53935 !important;
              color: #ffffff !important;
            }

            /* Sticky Close Button inside Drawer Header */
            .mobile-filter-close-btn {
              position: sticky !important;
              top: 0 !important;
              float: right !important;
              margin-bottom: 8px !important;
              width: 34px !important;
              height: 34px !important;
              border-radius: 50% !important;
              background: #f1f5f9 !important;
              border: none !important;
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
              font-size: 16px !important;
              color: #475569 !important;
              cursor: pointer !important;
              z-index: 1000 !important;
            }

            /* Profile Page VIP Redesign */
            .profile-page-wrapper {
              background: #f8fafc !important;
              min-height: 100vh !important;
              padding-bottom: 120px !important;
            }

            .profile-page-hero {
              background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #0f172a 100%) !important;
              border-radius: 0 0 32px 32px !important;
              padding: 24px 16px 28px !important;
              box-shadow: 0 12px 32px rgba(15, 23, 42, 0.22), 0 2px 0 rgba(229, 57, 53, 0.3) !important;
              position: relative !important;
              overflow: hidden !important;
            }

            .profile-hero-inner {
              display: flex !important;
              flex-direction: row !important;
              align-items: center !important;
              gap: 14px !important;
              position: relative !important;
              z-index: 2 !important;
            }

            .profile-avatar-large {
              width: 62px !important;
              height: 62px !important;
              min-width: 62px !important;
              border-radius: 50% !important;
              background: linear-gradient(135deg, #ef4444 0%, #b91c1c 100%) !important;
              border: 3.5px solid rgba(255, 255, 255, 0.35) !important;
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
              font-size: 24px !important;
              color: #ffffff !important;
              box-shadow: 0 6px 20px rgba(239, 68, 68, 0.45) !important;
            }

            .profile-hero-info {
              flex: 1 !important;
              min-width: 0 !important;
            }

            .profile-hero-name {
              font-size: 17px !important;
              font-weight: 800 !important;
              color: #ffffff !important;
              letter-spacing: -0.3px !important;
              margin: 0 !important;
              line-height: 1.25 !important;
              overflow: hidden !important;
              text-overflow: ellipsis !important;
              white-space: nowrap !important;
            }

            .profile-hero-info span {
              background: rgba(34, 197, 94, 0.18) !important;
              color: #4ade80 !important;
              border: 1px solid rgba(74, 222, 128, 0.4) !important;
              font-size: 11px !important;
              font-weight: 800 !important;
              padding: 2px 9px !important;
              border-radius: 14px !important;
              display: inline-flex !important;
              align-items: center !important;
            }

            .profile-hero-email {
              font-size: 12.5px !important;
              color: #cbd5e1 !important;
              margin-top: 4px !important;
              margin-bottom: 0 !important;
              overflow: hidden !important;
              text-overflow: ellipsis !important;
              white-space: nowrap !important;
              display: flex !important;
              align-items: center !important;
              gap: 6px !important;
            }

            .profile-hero-email i {
              color: #ef4444 !important;
              font-size: 12px !important;
            }

            .profile-hero-inner button.btn-light {
              background: rgba(255, 255, 255, 0.15) !important;
              color: #ffffff !important;
              border: 1.5px solid rgba(255, 255, 255, 0.3) !important;
              border-radius: 24px !important;
              padding: 7px 14px !important;
              font-size: 11.5px !important;
              font-weight: 700 !important;
              white-space: nowrap !important;
              box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15) !important;
              display: inline-flex !important;
              align-items: center !important;
              gap: 5px !important;
              transition: all 0.2s ease !important;
            }

            .profile-hero-inner button.btn-light:active {
              background: rgba(255, 255, 255, 0.28) !important;
              transform: scale(0.96) !important;
            }

            /* Profile Segmented Pill Tab Bar (Clean 3 Tabs, hides clutter) */
            .profile-page-body {
              padding: 16px 14px 110px !important;
              max-width: 600px !important;
              margin: 0 auto !important;
            }

            .profile-sidebar {
              width: 100% !important;
              margin-bottom: 16px !important;
            }

            .profile-sidebar-card {
              display: flex !important;
              flex-direction: row !important;
              background: #f1f5f9 !important;
              border-radius: 18px !important;
              padding: 5px !important;
              border: 1.5px solid #e2e8f0 !important;
              box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03) !important;
              gap: 4px !important;
            }

            .profile-sidebar-divider,
            .profile-sidebar-card a {
              display: none !important; /* Hides redundant Home, Shop, Wishlist links */
            }

            .profile-tab-btn {
              flex: 1 !important;
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
              text-align: center !important;
              padding: 10px 8px !important;
              border-radius: 14px !important;
              font-size: 12px !important;
              font-weight: 700 !important;
              color: #64748b !important;
              border: none !important;
              background: transparent !important;
              white-space: nowrap !important;
              gap: 6px !important;
              cursor: pointer !important;
              transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1) !important;
            }

            .profile-tab-btn i {
              font-size: 12px !important;
            }

            .profile-tab-btn.active {
              background: #ffffff !important;
              color: #ef4444 !important;
              box-shadow: 0 4px 14px rgba(0, 0, 0, 0.08) !important;
              font-weight: 800 !important;
            }

            .profile-tab-btn.active i {
              color: #ef4444 !important;
            }

            /* Profile Content Card */
            .profile-content-card {
              background: #ffffff !important;
              border-radius: 24px !important;
              border: 1px solid #e2e8f0 !important;
              box-shadow: 0 10px 30px rgba(0, 0, 0, 0.04) !important;
              padding: 20px 16px !important;
              overflow: hidden !important;
            }

            .profile-content-header {
              display: flex !important;
              justify-content: space-between !important;
              align-items: center !important;
              border-bottom: 1px solid #f1f5f9 !important;
              padding-bottom: 14px !important;
              margin-bottom: 16px !important;
            }

            .profile-content-header h2 {
              font-size: 16.5px !important;
              font-weight: 800 !important;
              color: #0f172a !important;
              margin: 0 !important;
            }

            .profile-content-header i {
              color: #ef4444 !important;
              font-size: 19px !important;
            }

            .profile-content-header .btn-outline-danger {
              border-radius: 20px !important;
              padding: 5px 14px !important;
              font-size: 11.5px !important;
              font-weight: 700 !important;
              border: 1.5px solid #ef4444 !important;
              color: #ef4444 !important;
              background: rgba(239, 68, 68, 0.04) !important;
              display: inline-flex !important;
              align-items: center !important;
              gap: 5px !important;
              transition: all 0.2s ease !important;
            }

            .profile-content-header .btn-outline-danger:active {
              background: #ef4444 !important;
              color: #ffffff !important;
            }

            /* Info Grid Modern Card Tiles */
            .profile-info-grid {
              display: flex !important;
              flex-direction: column !important;
              gap: 10px !important;
              margin-top: 8px !important;
            }

            .profile-info-item {
              background: #f8fafc !important;
              border: 1px solid #e2e8f0 !important;
              border-radius: 16px !important;
              padding: 13px 16px !important;
              display: flex !important;
              flex-direction: column !important;
              gap: 4px !important;
              transition: all 0.15s ease !important;
            }

            .profile-info-label {
              font-size: 11px !important;
              font-weight: 800 !important;
              color: #64748b !important;
              text-transform: uppercase !important;
              letter-spacing: 0.6px !important;
              display: flex !important;
              align-items: center !important;
              gap: 7px !important;
            }

            .profile-info-label i {
              color: #ef4444 !important;
              font-size: 12px !important;
              width: 16px !important;
              text-align: center !important;
            }

            .profile-info-value {
              font-size: 14.5px !important;
              font-weight: 700 !important;
              color: #0f172a !important;
              word-break: break-word !important;
              line-height: 1.4 !important;
              padding-left: 23px !important;
            }

            /* Form Elements */
            .profile-content-card form {
              padding: 10px 0 0 !important;
            }

            .profile-content-card .form-control {
              border-radius: 14px !important;
              border: 1.5px solid #cbd5e1 !important;
              padding: 10px 14px !important;
              font-size: 14px !important;
              color: #0f172a !important;
              background: #ffffff !important;
              box-shadow: none !important;
            }

            .profile-content-card .form-control:focus {
              border-color: #ef4444 !important;
              box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.12) !important;
            }

            .profile-content-card .form-label {
              font-size: 12.5px !important;
              font-weight: 700 !important;
              color: #334155 !important;
              margin-bottom: 6px !important;
            }

            .profile-content-card .btn-danger {
              background: #ef4444 !important;
              border-color: #ef4444 !important;
              border-radius: 14px !important;
              padding: 9px 18px !important;
              font-size: 12.5px !important;
              font-weight: 700 !important;
            }

            .profile-content-card .btn-outline-secondary {
              border-radius: 14px !important;
              padding: 9px 18px !important;
              font-size: 12.5px !important;
              font-weight: 700 !important;
            }

            /* Address Cards */
            .profile-address-card {
              border: 1.5px solid #e2e8f0 !important;
              border-radius: 18px !important;
              padding: 16px !important;
              background: #f8fafc !important;
              box-shadow: none !important;
              margin-bottom: 12px !important;
            }

            .profile-address-badge {
              background: linear-gradient(135deg, #ef4444, #dc2626) !important;
              color: #ffffff !important;
              border-radius: 14px !important;
              font-size: 11px !important;
              font-weight: 800 !important;
              padding: 3px 10px !important;
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

            /* Hide redundant header action icons on mobile */
            .header-actions {
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

      // 3. Setup Crisp Backdrop & Close Button for User Profile Center Modal
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
          document.body.style.overflow = 'hidden';

          // Add close button to header if not present
          var header = dropdown.querySelector('.user-dropdown-header');
          if (header && !header.querySelector('.user-dropdown-close-btn')) {
            var closeBtn = document.createElement('button');
            closeBtn.className = 'user-dropdown-close-btn';
            closeBtn.type = 'button';
            closeBtn.innerHTML = '✕';
            closeBtn.setAttribute('aria-label', 'Close');
            closeBtn.addEventListener('click', function(e) {
              e.stopPropagation();
              var btn = document.querySelector('.user-profile-btn');
              if (btn) btn.click();
            });
            header.appendChild(closeBtn);
          }
        } else if (userBackdrop) {
          userBackdrop.classList.remove('active');
          document.body.style.overflow = '';
        }
      }

      // 4. Mobile Filter Drawer DOM Setup
      function setupMobileFilter() {
        if (window.innerWidth > 991) return;

        var sidebar = document.querySelector('.products-filter-sidebar-col');
        if (!sidebar) return;

        var toolbar = document.querySelector('.catalog-toolbar');

        var backdrop = document.querySelector('.mobile-filter-backdrop');
        if (!backdrop) {
          backdrop = document.createElement('div');
          backdrop.className = 'mobile-filter-backdrop';
          document.body.appendChild(backdrop);
          backdrop.addEventListener('click', function() {
            closeDrawer();
          });
        }

        function openDrawer() {
          sidebar.classList.add('mobile-drawer-open');
          backdrop.classList.add('active');
          document.body.style.overflow = 'hidden';
        }

        function closeDrawer() {
          sidebar.classList.remove('mobile-drawer-open');
          backdrop.classList.remove('active');
          document.body.style.overflow = '';
        }

        if (!sidebar.querySelector('.mobile-filter-close-btn')) {
          var closeBtn = document.createElement('button');
          closeBtn.className = 'mobile-filter-close-btn';
          closeBtn.type = 'button';
          closeBtn.innerHTML = '✕';
          closeBtn.setAttribute('aria-label', 'Close Filters');
          closeBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            closeDrawer();
          });
          sidebar.insertBefore(closeBtn, sidebar.firstChild);
        }

        // Auto close drawer when user clicks "Show Products" or clear all inside drawer
        var buttons = sidebar.querySelectorAll('button');
        buttons.forEach(function(b) {
          if (b.innerText && (b.innerText.includes('Products') || b.innerText.includes('Show'))) {
            if (!b.__hasCloseListener) {
              b.__hasCloseListener = true;
              b.addEventListener('click', function() {
                setTimeout(closeDrawer, 300);
              });
            }
          }
        });

        if (toolbar && !toolbar.querySelector('.mobile-filter-toggle-btn')) {
          var filterBtn = document.createElement('button');
          filterBtn.className = 'mobile-filter-toggle-btn';
          filterBtn.type = 'button';

          var countTag = sidebar.querySelector('.filter-sidebar-count-tag');
          var countText = countTag ? countTag.innerText.trim() : '';

          filterBtn.innerHTML = '⚡ Filters' + (countText ? ' <span style="background:#E53935;color:#fff;border-radius:10px;padding:2px 7px;font-size:11px;margin-left:4px;">' + countText + '</span>' : '');

          filterBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            openDrawer();
          });

          toolbar.style.display = 'flex';
          toolbar.style.justifyContent = 'space-between';
          toolbar.style.alignItems = 'center';
          toolbar.insertBefore(filterBtn, toolbar.firstChild);
        }
      }

      // 5. Setup Profile Page layout and clean tab navigation
      function setupProfilePage() {
        var sidebarCard = document.querySelector('.profile-sidebar-card');
        if (sidebarCard) {
          // Hide redundant navigation links (Home, Shop, Wishlist) from profile tabs
          var links = sidebarCard.querySelectorAll('a, .profile-sidebar-divider');
          for (var i = 0; i < links.length; i++) {
            links[i].style.setProperty('display', 'none', 'important');
          }
        }
      }

      // 6. Setup App Header (Flipkart-style: Remove Voxo, hide Home/Products, add delivery badge, style search bar)
      function setupAppHeader() {
        var voxoLogos = document.querySelectorAll('.brand-logo-img, .login-brand-logo-img, .footer-brand-tag');
        for (var i = 0; i < voxoLogos.length; i++) {
          voxoLogos[i].style.setProperty('display', 'none', 'important');
        }

        // Hide desktop nav links (Home, Products, Categories) from top header
        var mainNav = document.querySelector('.main-nav');
        if (mainNav) {
          mainNav.style.setProperty('display', 'none', 'important');
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
              fetch('https://circuitpoint.circuitpointcare.com/api/wishlist', {
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
              fetch('https://circuitpoint.circuitpointcare.com/api/cart', {
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

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep link stream error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');
    if (uri.host == 'circuitpoint.circuitpointcare.com' || uri.host == 'rtest.epriceoffer.com') {
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
    for (int i = 0; i < _navItems.length; i++) {
      if (url.contains(_navItems[i].url)) {
        if (_currentIndex != i) {
          setState(() {
            _currentIndex = i;
          });
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<Map<String, String>?> _fetchUserData() async {
    try {
      final res = await _controller.runJavaScriptReturningResult('''
        (function() {
          try {
            var token = localStorage.getItem("token");
            var raw = localStorage.getItem("user");
            if (token && raw) {
              var u = JSON.parse(raw);
              return JSON.stringify({
                id: (u.virtual_id || u.virtualId || u.vid || u.user_main_id || u.id || u.userId || "").toString(),
                email: (u.email || "").toString(),
                name: (u.name || u.full_name || u.user_name || "User").toString()
              });
            }
          } catch(e) {}
          return "";
        })()
      ''');
      String clean = res.toString();
      if (clean.startsWith('"') && clean.endsWith('"')) {
        clean = clean.substring(1, clean.length - 1).replaceAll(r'\"', '"');
      }
      if (clean.isNotEmpty && clean != '""' && clean != 'null') {
        final Map<String, dynamic> data = jsonDecode(clean);
        final email = data['email']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';
        if (email.isNotEmpty || name.isNotEmpty) {
          return {
            'id': data['id']?.toString() ?? '',
            'email': email,
            'name': name.isNotEmpty ? name : 'User',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  void _showAccountBottomSheet() async {
    final user = await _fetchUserData();
    if (!mounted) return;
    final bool isLoggedIn = user != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              Container(
                width: 42,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Member Card (Logged In) OR Guest Welcome Card (Guest)
              if (isLoggedIn)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar with Gradient & Star Badge
                      Stack(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                            ),
                            child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB300),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star_rounded, color: Colors.black, size: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user['name'] ?? 'User',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'VIP',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user['email'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                )
              else
                // Guest Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome, Guest!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sign in to manage orders & fast checkout',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _controller.loadRequest(Uri.parse('$_baseUrl/login'));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // 3 Quick Action Cards (Orders, Wishlist, Cart)
              Row(
                children: [
                  _buildQuickAction(
                    icon: Icons.local_shipping_outlined,
                    label: 'My Orders',
                    color: const Color(0xFFE53935),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onBottomNavTapped(2); // Orders
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildQuickAction(
                    icon: Icons.favorite_border_rounded,
                    label: 'Wishlist',
                    color: const Color(0xFFE91E63),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onBottomNavTapped(3); // Wishlist
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildQuickAction(
                    icon: Icons.shopping_bag_outlined,
                    label: 'My Cart',
                    color: const Color(0xFF2E7D32),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onBottomNavTapped(4); // Cart
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Menu Items List
              if (isLoggedIn)
                _buildAccountMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  subtitle: 'Personal details, email & phone',
                  onTap: () {
                    Navigator.pop(ctx);
                    _controller.loadRequest(Uri.parse('$_baseUrl/profile'));
                  },
                ),
              _buildAccountMenuItem(
                icon: Icons.storefront_outlined,
                title: 'Shop Products',
                subtitle: 'Explore full electronics components catalog',
                onTap: () {
                  Navigator.pop(ctx);
                  _controller.loadRequest(Uri.parse('$_baseUrl/products'));
                },
              ),
              _buildAccountMenuItem(
                icon: Icons.grid_view_outlined,
                title: 'Browse Categories',
                subtitle: 'Sensors, dev boards, ICs & modules',
                onTap: () {
                  Navigator.pop(ctx);
                  _controller.loadRequest(Uri.parse('$_baseUrl/categories'));
                },
              ),
              if (isLoggedIn)
                _buildAccountMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Delivery Addresses',
                  subtitle: 'Add or manage shipping locations',
                  onTap: () {
                    Navigator.pop(ctx);
                    _controller.runJavaScript('window.dispatchEvent(new CustomEvent("open-address-modal"));');
                  },
                )
              else
                _buildAccountMenuItem(
                  icon: Icons.login_rounded,
                  title: 'Sign In / Register',
                  subtitle: 'Login with your account or create a new one',
                  onTap: () {
                    Navigator.pop(ctx);
                    _controller.loadRequest(Uri.parse('$_baseUrl/login'));
                  },
                ),

              if (isLoggedIn) ...[
                const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),

                // Logout Button
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _controller.runJavaScript('''
                      localStorage.removeItem("token");
                      localStorage.removeItem("user");
                      window.dispatchEvent(new Event("user-profile-updated"));
                      window.location.reload();
                    ''');
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFFF87171), size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8.5),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF475569), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    final item = _navItems[index];

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

    // Account Trigger -> Opens Native Gethu VIP Account Bottom Sheet (0% blur, 100% crisp!)
    if (item.url == '/profile') {
      _showAccountBottomSheet();
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
        'Boolean(document.querySelector(".user-dropdown-card"))',
      );
      if (isDropdownOpen == true || isDropdownOpen.toString() == 'true') {
        await _controller.runJavaScript('''
          var profileBtn = document.querySelector(".user-profile-btn");
          if (profileBtn) profileBtn.click();
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
        'Boolean(document.querySelector(".products-filter-sidebar-col.mobile-drawer-open"))',
      );
      if (isDrawerOpen == true || isDrawerOpen.toString() == 'true') {
        await _controller.runJavaScript('''
          document.querySelector(".products-filter-sidebar-col")?.classList.remove("mobile-drawer-open");
          document.querySelector(".mobile-filter-backdrop")?.classList.remove("active");
          document.body.style.overflow = "";
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
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reloadPage,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                      color: isSelected ? const Color(0xFFE53935) : Colors.grey.shade600,
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
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? const Color(0xFFE53935) : Colors.grey.shade700,
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
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
