
// ignore_for_file: deprecated_member_use

import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/pages/home_content/dashboard_page.dart';
import 'package:admin_vote_mobile/pages/home_content/hasil_vote.dart';
import 'package:admin_vote_mobile/pages/home_content/setting.dart';
import 'package:admin_vote_mobile/pages/home_content/vote_saya_page.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HomePage extends StatefulWidget {
  final bool fromLogout;
  final int initialIndex;

  const HomePage({
    super.key,
    this.fromLogout = false,
    this.initialIndex = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? langCode;
  String? token;
  String? lastPressedMessage;

  DateTime? lastPressed;

  final prefs = FlutterSecureStorage();
  Map<String, dynamic> bahasa = {};

  List<Widget> get _pages => [
    DashboardPage(onNavigateToTab: _onNavTap),
    VoteSayaPage(onNavigateToTab: _onNavTap),
    HasilVotePage(onNavigateToTab: _onNavTap),
    SettingPage(
      key: _settingKey,
      onNavigateToTab: _onNavTap
    ),
  ];

  int _selectedIndex = 0;

  final GlobalKey<SettingPageState> _settingKey =
    GlobalKey<SettingPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
    
      if (!mounted) return;
      
      await _getBahasa();
    });
  }

  Future<void> _getBahasa() async {
    if (!mounted) return;
    final templangCode = await StorageService.getLanguage();
    
    if (!mounted) return;
    setState(() {
      langCode = templangCode;
    });
    
    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");

    if (!mounted) return;
    setState(() {
      bahasa = tempbahasa;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();

        if (lastPressed == null ||
            now.difference(lastPressed!) > const Duration(seconds: 2)) {
          lastPressed = now;
          Fluttertoast.showToast(
            msg: lastPressedMessage!,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );

          return false;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.white,
          toolbarHeight: 0,
        ),

        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: langNotifier,
          builder: (context, value, _) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _getBahasa();
              });
            }

            return BottomAppBar(
              color: Colors.white,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_outlined, bahasa['bot_nav_1'] ?? "Dashboard", 0),
                    _buildNavItem(Icons.calendar_today_outlined, bahasa['bot_nav_2'] ?? "Vote Saya", 1),
                    _buildNavItem(Icons.stacked_bar_chart_outlined, bahasa['bot_nav_3'] ?? "Hasil Vote", 2),
                    _buildNavItem(Icons.settings_outlined, bahasa['bot_nav_4'] ?? "Pengaturan", 3),
                  ],
                ),
              ),
            );
          },
        ),

        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          _onNavTap(index);
        },

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.red : Colors.grey),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _settingKey.currentState?.openAkunKeamanan();
      });
    }
  }
}