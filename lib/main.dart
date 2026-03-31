import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double _fontScalePercent = 0.0;
  double _iconScalePercent = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontScalePercent = prefs.getDouble('font_scale_percent') ?? 0.0;
      _iconScalePercent = prefs.getDouble('icon_scale_percent') ?? 0.0;
      _isLoading = false;
    });
  }

  double get _fontScale => 1.0 + _fontScalePercent;
  double get _iconScale => 1.0 + _iconScalePercent;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Al Hal Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 28 * _fontScale),
          displayMedium: TextStyle(fontSize: 24 * _fontScale),
          displaySmall: TextStyle(fontSize: 20 * _fontScale),
          headlineLarge: TextStyle(fontSize: 24 * _fontScale),
          headlineMedium: TextStyle(fontSize: 20 * _fontScale),
          headlineSmall: TextStyle(fontSize: 16 * _fontScale),
          titleLarge: TextStyle(fontSize: 18 * _fontScale),
          titleMedium: TextStyle(fontSize: 16 * _fontScale),
          titleSmall: TextStyle(fontSize: 14 * _fontScale),
          bodyLarge: TextStyle(fontSize: 14 * _fontScale),
          bodyMedium: TextStyle(fontSize: 12 * _fontScale),
          bodySmall: TextStyle(fontSize: 10 * _fontScale),
          labelLarge: TextStyle(fontSize: 14 * _fontScale),
          labelMedium: TextStyle(fontSize: 12 * _fontScale),
          labelSmall: TextStyle(fontSize: 10 * _fontScale),
        ),
        iconTheme: IconThemeData(size: 24 * _iconScale),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(iconSize: 24 * _iconScale),
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 18 * _fontScale,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(
            size: 24 * _iconScale,
            color: Colors.white,
          ),
          toolbarTextStyle: TextStyle(
            fontSize: 14 * _fontScale,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: TextStyle(fontSize: 14 * _fontScale),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: TextStyle(fontSize: 14 * _fontScale),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: TextStyle(fontSize: 14 * _fontScale),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 14 * _fontScale),
          hintStyle: TextStyle(fontSize: 12 * _fontScale),
          errorStyle: TextStyle(fontSize: 10 * _fontScale),
        ),
        listTileTheme: ListTileThemeData(
          titleTextStyle: TextStyle(fontSize: 14 * _fontScale),
          subtitleTextStyle: TextStyle(fontSize: 12 * _fontScale),
        ),
        snackBarTheme: SnackBarThemeData(
          contentTextStyle: TextStyle(fontSize: 12 * _fontScale),
        ),
      ),
      home: const LoginScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_fontScale),
          ),
          child: child!,
        );
      },
    );
  }
}
//
/*
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart'; // استيراد شاشة التفعيل

void main() async {
  // التأكد من تهيئة Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // قفل اتجاه التطبيق
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // التحقق من حالة التفعيل
  final prefs = await SharedPreferences.getInstance();
  final String activationStatus = prefs.getString('activation_status') ?? '';

  bool isActivated = false;
  if (activationStatus.isNotEmpty) {
    try {
      // فك التشفير البسيط والتحقق من القيمة
      final decodedStatus = utf8.decode(base64.decode(activationStatus));
      if (decodedStatus == 'activated_ok') {
        isActivated = true;
      }
    } catch (e) {
      // في حال وجود قيمة خاطئة أو قديمة
      isActivated = false;
    }
  }

  runApp(MyApp(isActivated: isActivated));
}

class MyApp extends StatelessWidget {
  final bool isActivated;

  const MyApp({super.key, required this.isActivated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Hal Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      // تحديد الشاشة الرئيسية بناءً على حالة التفعيل
      home: isActivated ? const LoginScreen() : const ActivationScreen(),
    );
  }
}
*/
