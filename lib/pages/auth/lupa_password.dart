// ignore_for_file: use_build_context_synchronously

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

class LupaPasswordPage extends StatefulWidget {
  const LupaPasswordPage({super.key,});

  @override
  State<LupaPasswordPage> createState() => _LupaPasswordPageState();
}

class _LupaPasswordPageState extends State<LupaPasswordPage> {
  String? langCode, token;
  String? lupaPassword, lupaPasswordDesc, emailHint, sendEmail, requestSend;
  Map<String, dynamic> bahasa = {};

  bool isLoading = true;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
    });
  }

  Future<void> _getBahasa() async {
    token = await StorageService.getToken();
    final code = await StorageService.getLanguage();

    setState(() {
      langCode = code;
    });
    
    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");

    setState(() {
      lupaPassword = tempbahasa["lupa_password"];
      lupaPasswordDesc = tempbahasa["lupa_password_desc"];
      emailHint = tempbahasa["input_email"];
      sendEmail = tempbahasa["kirim_email"];
      requestSend = tempbahasa["request_kirim"];

      bahasa = tempbahasa;

      isLoading = false;
    });
  }

  bool get _isFormFilled => _emailController.text.isNotEmpty;
  
  bool _emailTouched = false;

  int errorCode = 0;

  String? emailError, emailError2;
  Map<String, dynamic> errorMessage = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
        ? Center(child: CircularProgressIndicator(color: Colors.red,),)
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                scrolledUnderElevation: 0,
                title: Text(lupaPassword!),
                centerTitle: false,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              body: Container(
                height: MediaQuery.of(context).size.height,
                color: Colors.white,
                padding: kGlobalPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      lupaPasswordDesc!,
                    ),

                    const SizedBox(height: 20),
                    Align(
                      alignment: AlignmentGeometry.centerLeft,
                      child: Text(
                        "Email",
                      ),
                    ),
                    TextField(
                      controller: _emailController,
                      autofocus: false,
                      onChanged: (value) {
                        if (!_emailTouched) {
                          setState(() {
                            _emailTouched = true;
                            errorCode = 0;
                          });
                        } else {
                          setState(() {
                            errorCode = 0;
                          });
                        }
                      },
                      inputFormatters: [
                        EmailInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: emailHint!,
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    if (_emailTouched && !isValidEmail(_emailController.text.trim()))
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 0, 0),
                        child: Text(
                          bahasa['error_email_1'],
                          style: TextStyle(color: Colors.red[900], fontSize: 12),
                        ),
                      ),

                    if (errorCode == 422 && errorMessage['email'] != null)
                      ...((errorMessage['email'] as List).map((e) => Align(
                        alignment: AlignmentGeometry.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 0, 0),
                          child: Text(
                            translateError(e.toString(), langCode),
                            style: TextStyle(color: Colors.red[900], fontSize: 12),
                          ),
                        ),
                      ))),

                    if (errorCode == 500)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 0, 0),
                        child: Text(
                          bahasa['error_email_4'], // atau pesan khusus dari server
                          style: TextStyle(color: Colors.red[900], fontSize: 12),
                        ),
                      ),

                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
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
                        onPressed: _isFormFilled ? _doResetPassword : null,
                        child: Text(
                          sendEmail!,
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ),
    );
  }

  void _doResetPassword () async {
    showLoadingDialog(context, bahasa['loading_email'] ?? "Mengirim email...");
    
    final body = {
      "email": _emailController.text
    };

    final result = await ApiService.post('/forgot-password', body: body, xLanguage: langCode, token: token);
    if(result?['rc'] == 200) {
      setState(() => errorCode = 200);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.topSlide,
        title: requestSend!,
        desc: bahasa['email_kirim'], //"Permintaan reset password berhasil dikirim. Silakan cek email Anda.",
        btnOkOnPress: () {},
        btnOkColor: Colors.red,
        buttonsTextStyle: TextStyle(color: Colors.white),
        headerAnimationLoop: false,
        dismissOnTouchOutside: true,
        showCloseIcon: true,
      ).show().then((_) {
        hideLoadingDialog(context);
        Navigator.pop(context);
      });
    } else if (result?['rc'] == 422) {

      final data = result?['data'];
      String desc = '';
      if (data is Map<String, dynamic>) {
        
        if (data['email'] is List) {
          for (var msg in data['email']) {
            final translated = translateError(msg.toString(), langCode);
            final lower = translated.toLowerCase();

            if (lower.contains('registered') || lower.contains('terdaftar')) {
              emailError = translated;
            } else if (lower.contains('valid domain') || lower.contains('domain yang valid')) {
              emailError2 = translated;
            }
          }
        }

        final errorMessages = data.values
          .whereType<List>()
          .expand((e) => e)
          .whereType<String>()
          .map((e) => translateError(e, langCode))
          .toList();

        desc = errorMessages.join('\n');
      }
      errorCode = result?['rc'] ?? 0;
      errorMessage = data;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.topSlide,
        title: bahasa['maaf'],
        desc: desc,
        btnOkOnPress: () {
          setState(() {});
        },
        btnOkColor: Colors.red,
        buttonsTextStyle: TextStyle(color: Colors.white),
        headerAnimationLoop: false,
        dismissOnTouchOutside: true,
        showCloseIcon: true,
      ).show().then((_) {
        hideLoadingDialog(context);
      });
    } else if (result?['rc'] == 500) {
      setState(() => errorCode = 500);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.topSlide,
        title: bahasa['maaf'],
        desc: bahasa['error_email_4'], // atau pesan khusus dari server
        btnOkOnPress: () {
          setState(() {});
        },
        btnOkColor: Colors.red,
        buttonsTextStyle: TextStyle(color: Colors.white),
        headerAnimationLoop: false,
        dismissOnTouchOutside: true,
        showCloseIcon: true,
      ).show().then((_) {
        hideLoadingDialog(context);
      });
    } else {

      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.topSlide,
        title: bahasa['maaf'],
        desc: bahasa['error'], //"Terjadi kesalahan. Silakan coba lagi.",
        btnOkOnPress: () {},
        btnOkColor: Colors.red,
        buttonsTextStyle: TextStyle(color: Colors.white),
        headerAnimationLoop: false,
        dismissOnTouchOutside: true,
        showCloseIcon: true,
      ).show().then((_) {
        hideLoadingDialog(context);
      });
    }
  }

  String translateError(String message, String? langCode) {
    if (langCode == 'id') {
      return message;
    }

    final normalized = message.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');

    for (final entry in errorTranslationMap.entries) {
      final key = entry.key.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');

      if (normalized.contains(key)) {
        return entry.value;
      }
    }

    return message;
  }
}