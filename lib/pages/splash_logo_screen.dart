
import 'package:admin_vote_mobile/pages/auth/login_page.dart';
import 'package:admin_vote_mobile/pages/home_page.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashLogoPage extends StatefulWidget {
  const SplashLogoPage({super.key});

  @override
  State<SplashLogoPage> createState() => _SplashLogoPageState();
}

class _SplashLogoPageState extends State<SplashLogoPage> {
  String appVersion = "";
  String? langCode;
  String? token;
  Map<String, dynamic>? getUserData;
  bool isTokenValid = false;
  Map<String, dynamic>? bahasa;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadVersion();
      await _checkToken();
      
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _navigate();
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      appVersion = "v${info.version}";
    });

    await StorageService.setLanguage("id");
  }

  Future<void> _checkToken() async {
    final storedToken = await StorageService.getToken();
    final storedUserData = await StorageService.getUser();

    bool valid = false;

    if (storedToken != null && storedToken.isNotEmpty) {
      try {
        valid = !JwtDecoder.isExpired(storedToken);
      } catch (e) {
        valid = false;
      }
    }
    
    if (storedToken != null && !valid) {
      await StorageService.removeToken();
      await StorageService.removeRefreshToken();
      await StorageService.clearUser();
    }

    if (!mounted) return;
    setState(() {
      token = valid ? storedToken : null;
      getUserData = valid ? storedUserData : null;
      isTokenValid = valid;
    });
  }

  void _navigate() {
    if (!isTokenValid || token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Image.asset(
              'assets/images/KreenOriginal.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: 20,
            child: Text(
              appVersion.isNotEmpty ? appVersion : "",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}