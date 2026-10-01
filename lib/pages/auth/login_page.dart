// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously, deprecated_member_use, prefer_interpolation_to_compose_strings

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/pages/auth/lupa_password.dart';
import 'package:admin_vote_mobile/pages/home_page.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  final bool notLog;
  const LoginPage({super.key, this.notLog = false,});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final prefs = FlutterSecureStorage();
  String? langCode;
  bool isLoading = true;
  bool? changed;

  bool get _isFormFilled =>
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  bool _lockPasswordField = false;
  
  String? PasswordError, PasswordError2, PasswordError3;
  String? confirmPasswordError;

  int errorCode = 0;
  String? errorMessage;

  OutlineInputBorder _border(bool isFilled) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isFilled ? Colors.orange : Colors.grey.shade400,
        width: 1.5,
      ),
    );
  }

  void _doLogin() async {
    showLoadingDialog(context, bahasa!['loading']);
    
    final body = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };
    
    final result = await ApiService.postLogin("/api/v1/auth/login", body: body, xLanguage: langCode);

    if (!mounted) return;

    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      errorCode = 200;
      final user = result['data']['user'];
      final token = result['data']['access_token'];
      final refreshToken = result['data']['refresh_token'];

      await StorageService.setToken(token);
      await StorageService.setRefreshToken(refreshToken);
      await StorageService.setUser(
        id: user['id'], 
        id_merchant: user['id_merchant'],
        name: user['name'],
        userName: user['username'],
        email: user['email'],
        phone: user['phone'],
        level: user['level'],
      );

      if (widget.notLog) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } else if (result != null &&
        result['message'] is String &&
        (result['message'] as String).isNotEmpty &&
        result['success'] != false) {
      errorCode = 401;
      final rawMessage = result['message'] as String;
      final translated = translateError(rawMessage, langCode);

      errorMessage = translated;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.topSlide,
        title: bahasa!['maaf'],
        desc: translated,
        btnOkOnPress: () {
          setState(() {});
        },
        btnOkColor: Colors.red,
        buttonsTextStyle: TextStyle(color: Colors.white),
        headerAnimationLoop: false,
        dismissOnTouchOutside: true,
        showCloseIcon: true,
      ).show();
    } else {
      errorCode = 500;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.topSlide,
        title: bahasa!['maaf'],
        desc: bahasa!['error'], //"Terjadi kesalahan. Silakan coba lagi.",
        btnOkOnPress: () {},
        btnOkColor: Colors.red,
        buttonsTextStyle: TextStyle(color: Colors.white),
        headerAnimationLoop: false,
        dismissOnTouchOutside: true,
        showCloseIcon: true,
      ).show();
    }
  }
  
  Map<String, dynamic>? bahasa;
  Future<void> _getBahasa() async {
    final templangCode = await StorageService.getLanguage();
    
    setState(() {
      langCode = templangCode;
    });
    
    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");

    setState(() {
      bahasa = tempbahasa;

      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
        ? Center(child: CircularProgressIndicator(color: Colors.red,),)
        : buildKonten(),
    );
  }

  Widget buildKonten() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(bahasa?['login'] ?? 'Login', style: TextStyle(color: Colors.black),),
        centerTitle: false,
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back_ios),
        //   onPressed: () {
        //     if (changed == true) {
        //       Navigator.pop(context, true);
        //     } else {
        //       Navigator.pop(context);
        //     }
        //   },
        // ),
      ),

      body: Center(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  
                  Column(
                    children: [
                      Image.asset(
                        "assets/images/img_homekreen.png",
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                  
                  const SizedBox(height: 35),
                  TextField(
                    controller: _emailController,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      EmailInputFormatter(),
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-Z0-9@._+\-]"),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: bahasa?['input_email'] ?? 'Email',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: _border(_emailController.text.isNotEmpty),
                      focusedBorder: _border(true),
                    ),
                  ),
                    
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    readOnly: _lockPasswordField,
                    keyboardType: TextInputType.visiblePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: bahasa?['input_password'] ?? 'Password',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: _border(_passwordController.text.isNotEmpty),
                      focusedBorder: _border(true),
                      suffixIcon: InkWell(
                        onTap: () async {
                          _unfocusAll(context);
                          setState(() {
                            _lockPasswordField = true;
                            _obscurePassword = !_obscurePassword;
                          });

                          await Future.delayed(const Duration(milliseconds: 30));

                          setState(() {
                            _lockPasswordField = false;
                          });
                        },
                        child: Icon(
                          _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        ),
                      )
                    ),
                  ),

                  if (errorCode != 200 && errorMessage != null) 
                    Align(
                      alignment: AlignmentGeometry.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 0, 0),
                          child: Text(
                            errorMessage ?? '',
                            style: TextStyle(color: Colors.red[900], fontSize: 12),
                          ),
                      ),
                    ),
                    
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LupaPasswordPage(),
                          ),
                        );
                      },
                      child: Text(
                        "${bahasa?['lupa_password'] ?? 'Lupa Password'} ?",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return Colors.grey;
                          }
                          return Colors.red;
                        }),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      onPressed: _isFormFilled ? _doLogin : null,
                      child: Text(
                        bahasa?['login'] ?? 'Login',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _unfocusAll(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}