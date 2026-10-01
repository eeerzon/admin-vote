import 'package:flutter/material.dart';

const EdgeInsets kGlobalPadding = EdgeInsets.all(20);

// ganti value sesuai kebutuhan
//====================================================================================

const String baseUrl = "https://newvote.kreenconnect.com";
const String baseCustomWeb = "dev.votingme.com";

const String formatDateEn = "MMM d, yyyy";
const String formatDateId = "dd MMM yyyy";
const String formatDay = "EEEE";

String? userCurrency = 'IDR';
String? lastCurrency;

int isChoosed = 1; // 0 = belum pilih, 1 = sudah pilih

ValueNotifier<bool> orderNeedRefresh = ValueNotifier(false);

// Dipakai new_vote.dart buat notify VoteSayaPage waktu popUntil balik ke
// root setelah "Simpan Draft" - supaya tab Draft otomatis kebuka lagi,
// gak peduli new_vote.dart dibuka dari VoteSayaPage langsung atau dari
// DetailVotePage (edit).
final RouteObserver<PageRoute> voteRouteObserver = RouteObserver<PageRoute>();
bool pendingSwitchToDraftTab = false;

ValueNotifier<String> langNotifier = ValueNotifier('id');

final Map<String, String> languages = {
  "id": "Indonesia",
  "en": "English",
};

final Map<String, String> currencies = {
  "EUR": "Euro",
  "IDR": "Indonesian Rupiah",
  "MYR": "Malaysian Ringgit",
  "PHP": "Philippine Peso",
  "SGD": "Singapore Dollar",
  "THB": "Thai Baht",
  "USD": "US Dollar",
  "VND": "Vietnamese Dong",
};

final Map<String, String> errorTranslationMap = {
  "Email diperlukan": 'Email is required',

  "Email tidak terdaftar": 'Email is not registered',

  "Email sudah terdaftar": 'Email is already registered',

  'Email harus berupa email yang valid': 'Email must be a valid email',

  'Email harus alamat email yang valid': 'Email must be a valid email address',

  'Email harus memiliki domain yang valid': 'Email must have a valid domain',

  'Nomor telepon minimal 7 karakter': 'Phone number at least 7 characters',

  "Password diperlukan": 'Password is required',

  'Password minimal 8 karakter': 'Password must be at least 8 characters',

  'Password harus mengandung setidaknya satu huruf dan satu angka':
      'Password must contain at least one letter and one number',

  'Password tidak cocok': 'Password does not match',
  

  'Password saat ini minimal 8 karakter':
      'Current password must be at least 8 characters',
  'Current password minimal 8 karakter':
      'Current password must be at least 8 characters',
  'Current password diperlukan': 'Current password is required',
  'Password saat ini salah': 'Current password is incorrect',
  'Password saat ini tidak sesuai': 'Current password is incorrect',
  

  'new password minimal 8 karakter':
      'New password must be at least 8 characters',
  'New password diperlukan': 'New password is required',


  'Konfirmasi password tidak cocok':
      'Confirm password does not match',
  'Confirm password diperlukan': 'Confirm password is required',

  'Format password tidak valid': 'Password format is invalid',

  'Email atau password salah.': 'Email or password is incorrect',
};


final Map<String, String> idNormalizationMap = {
  'Nomor telepon minimal 7 karakter': 'Nomor handphone harus minimal 7 karakter',
  'email harus memiliki domain yang valid.': 'Email harus memiliki domain yang valid',
  'Current password minimal 8 karakter': 'Kata sandi lama minimal 8 karakter',
  'Current password diperlukan': 'Kata sandi lama diperlukan',
  'Password saat ini salah': 'Kata sandi lama salah',
  'Password saat ini tidak sesuai': 'Kata sandi lama tidak sesuai',
  'Password saat ini minimal 8 karakter': 'Kata sandi lama minimal 8 karakter',
  'New password minimal 8 karakter': 'Kata sandi baru minimal 8 karakter',
  'New password diperlukan': 'Kata sandi baru diperlukan',
  'Confirm password diperlukan': 'Konfirmasi kata sandi diperlukan',
  'Konfirmasi password tidak cocok': 'Konfirmasi kata sandi tidak cocok',
  'Format password tidak valid': 'Format kata sandi tidak valid',
  'Password diperlukan': 'Password diperlukan',
  'Password minimal 8 karakter': 'Kata sandi minimal 8 karakter',
  'Password harus mengandung setidaknya satu huruf dan satu angka': 'Kata sandi harus mengandung setidaknya satu huruf dan satu angka',
  'Password tidak cocok': 'Kata sandi tidak cocok',
  'Email atau password salah.': 'Email atau kata sandi salah.',
};

Map<String, Color> colorMap = {
  'Blue': Colors.blue,
  'Red': Colors.red,
  'Green': Colors.green,
  'Yellow': Colors.yellow,
  'Purple': Colors.purple,
  'Orange': Colors.orange,
  'Pink': Colors.pink,
  'Grey': Colors.grey,
  'Turqoise': Colors.teal,
  'Gold': Color.fromRGBO(206, 138, 11, 1),
};