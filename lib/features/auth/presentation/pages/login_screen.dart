import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:circuit_point/features/home/presentation/pages/main_navigation_screen.dart';

class CaptchaCategory {
  final int id;
  final String categoryName;
  final String image;
  CaptchaCategory({required this.id, required this.categoryName, required this.image});

  factory CaptchaCategory.fromJson(Map<String, dynamic> json) {
    return CaptchaCategory(
      id: json['id'],
      categoryName: json['category_name'] ?? '',
      image: json['image'] ?? '',
    );
  }
}

enum LoginStep { username, password, captcha }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController inputController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  LoginStep _currentStep = LoginStep.username;
  bool _isCheckingApi = false;

  List<CaptchaCategory> _captchaCategories = [];
  int? _selectedCaptchaId;

  @override
  void dispose() {
    inputController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool isEmailInput(String input) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(input);
  }

  Future<void> _continueAction() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final input = inputController.text.trim();

    if (_currentStep == LoginStep.username) {
      setState(() {
        _isCheckingApi = true;
      });

      final bool isEmail = isEmailInput(input);
      final String endpoint = isEmail ? 'check-email' : 'check-phone';
      final String url = 'https://user.jobes24x7.com/api/login/$endpoint/$input';

      bool? exists;
      try {
        final response = await Dio().get(
          url,
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (response.data['data'] != null && response.data['data']['exists'] == true) {
            exists = true;
          } else {
            exists = false;
          }
        }
      } catch (e) {
        debugPrint('API Check Error: $e');
        exists = null; 
      }

      if (!mounted) return;
      setState(() {
        _isCheckingApi = false;
      });

      if (exists == true) {
        setState(() {
          _currentStep = LoginStep.password;
        });
      } else if (exists == false) {
        _showRegistrationRedirect(input);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to server. Try again.'), backgroundColor: Colors.red),
        );
      }
    } else if (_currentStep == LoginStep.password) {
      await _authenticateUser(identifier: input, password: passwordController.text);
    }
  }

  Future<void> _authenticateUser({required String identifier, required String password, int? captchaId}) async {
    setState(() {
      _isCheckingApi = true;
    });

    final bool isEmail = isEmailInput(identifier);
    final Map<String, dynamic> body = {
      'password': password,
    };
    if (isEmail) {
      body['email'] = identifier;
    } else {
      body['phone_number'] = identifier;
    }
    if (captchaId != null) {
      body['captcha_image_id'] = captchaId;
    }

    try {
      final response = await Dio().post(
        'https://managelogin.jobes24x7.com/api/login/authenticate',
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        bool success = false;

        if (data['code'] == 200 || 
            data['result'] == 'Success' || 
            data['result'] == 'success' || 
            data['success'] == true) {
          success = true;
        }
        if (data['data'] != null && data['data'] is Map) {
          if (data['data']['code'] == 200 || 
              data['data']['result'] == 'Success' || 
              data['data']['result'] == 'success' ||
              data['data']['success'] == true) {
            success = true;
          }
        }

        if (success) {
          if (captchaId == null) {
            // ALWAYS show Captcha categories after password validation
            await _fetchCaptchaCategories();
            if (!mounted) return;
            setState(() {
              _isCheckingApi = false;
              _currentStep = LoginStep.captcha;
            });
            return;
          }

          // SUCCESSFUL LOGIN (after selecting captcha)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
            (Route<dynamic> route) => false,
          );
          return;
        } else {
          _showError(data['message'] ?? (data['data'] is Map ? data['data']['message'] : null) ?? 'Invalid credentials');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response != null && e.response?.data is Map) {
          final data = e.response?.data;
          _showError(data['message'] ?? data['data']?['message'] ?? 'Authentication failed');
        } else {
          _showError('Connection error. Please check your internet.');
        }
      } else {
        _showError('Authentication failed: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingApi = false;
      });
    }
  }

  Future<void> _fetchCaptchaCategories() async {
    try {
      final response = await Dio().get(
        'https://managelogin.jobes24x7.com/api/outsideapis/captcha/category',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> catData = data['data'];
          final categories = catData.map((json) => CaptchaCategory.fromJson(json)).toList();
          categories.shuffle();
          setState(() {
            _captchaCategories = categories;
          });
        }
      }
    } catch (e) {
      debugPrint('Captcha fetch error: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)), 
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showRegistrationRedirect(String identifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151921).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 48,
                    color: Color(0xFFFF3B30),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'New Explorer?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No coordinates found for $identifier.\nPlease choose a platform to forge your path.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final Uri url = Uri.parse('https://managelogin.jobes24x7.com/');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not launch URL')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.language_rounded, color: Colors.white),
                    label: const Text(
                      'Access Web Portal', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      elevation: 10,
                      shadowColor: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final Uri url = Uri.parse('https://play.google.com/store/apps/details?id=com.sva.businessuser');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not launch URL')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.shop_rounded, color: Colors.white),
                    label: const Text(
                      'Download Android App', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2430),
                      elevation: 5,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel Operation',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaptchaGrid() {
    if (_captchaCategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFF3B30)),
            strokeWidth: 4,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security Protocol',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your registered secret image to confirm your identity securely.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: _captchaCategories.length,
          itemBuilder: (context, index) {
            final category = _captchaCategories[index];
            final isSelected = _selectedCaptchaId == category.id;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCaptchaId = category.id;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF3B30) : Colors.transparent,
                    width: isSelected ? 3.0 : 0.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    category.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1E2430),
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF3B30), Color(0xFFD32F2F)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isCheckingApi || _selectedCaptchaId == null
                ? null
                : () {
                    _authenticateUser(
                      identifier: inputController.text.trim(),
                      password: passwordController.text,
                      captchaId: _selectedCaptchaId,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: _isCheckingApi
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Authenticate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _currentStep = LoginStep.password;
                _selectedCaptchaId = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text(
              'Back to Password',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Column(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, left: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E2430), Color(0xFF151921)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.bolt_rounded, size: 60, color: Color(0xFFFF3B30)),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Circuit Point',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The Premium Tech Destination',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131822).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          child: _currentStep == LoginStep.captcha
                              ? _buildCaptchaGrid()
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentStep == LoginStep.password 
                                            ? 'Secure Access'
                                            : 'Welcome Back',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _currentStep == LoginStep.password 
                                          ? 'Enter your classified password to proceed.'
                                          : 'Enter your Mobile Number or Email.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 40),
                                      if (_currentStep == LoginStep.username) ...[
                                        Text(
                                          'CREDENTIALS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(alpha: 0.4),
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: inputController,
                                          keyboardType: TextInputType.emailAddress,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Email or Mobile Number',
                                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w600),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                                            filled: true,
                                            fillColor: const Color(0xFF0B0F19),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 2),
                                            ),
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                                              child: Icon(Icons.person_outline_rounded, color: Colors.white.withValues(alpha: 0.5)),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Please enter your credentials';
                                            }
                                            return null;
                                          },
                                        ),
                                      ] else if (_currentStep == LoginStep.password) ...[
                                        Text(
                                          'PASSWORD',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(alpha: 0.4),
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: passwordController,
                                          obscureText: !_isPasswordVisible,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Enter secret password',
                                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w600),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                                            filled: true,
                                            fillColor: const Color(0xFF0B0F19),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 2),
                                            ),
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                                              child: Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.5)),
                                            ),
                                            suffixIcon: Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: Icon(
                                                  _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                                  color: Colors.white.withValues(alpha: 0.5),
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _isPasswordVisible = !_isPasswordVisible;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Password is required';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {},
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                color: Color(0xFFFF3B30),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 40),
                                      Container(
                                        width: double.infinity,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF3B30), Color(0xFFD32F2F)],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isCheckingApi ? null : _continueAction,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: _isCheckingApi
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : Text(
                                                  _currentStep == LoginStep.password ? 'Secure Sign In' : 'Continue',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (_currentStep == LoginStep.password)
                                        Center(
                                          child: TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _currentStep = LoginStep.username;
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white.withValues(alpha: 0.6),
                                            ),
                                            child: const Text(
                                              'Change Account',
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        )
                                      else
                                        Center(
                                          child: RichText(
                                            text: TextSpan(
                                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), height: 1.6, fontWeight: FontWeight.w500),
                                              children: const [
                                                TextSpan(text: 'By proceeding, you agree to Circuit Point\'s\n'),
                                                TextSpan(text: 'Terms of Use', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                                TextSpan(text: ' and '),
                                                TextSpan(text: 'Privacy Policy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                              ],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded, size: 20, color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                      Text(
                        'Secured by Military-Grade Encryption',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
