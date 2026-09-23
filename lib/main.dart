import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:note_app/screens/main_navigation.dart';
import 'package:note_app/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDark = await SettingsService.isDarkMode();
  final fontSize = await SettingsService.getFontSize();

  runApp(MainApp(
    initialIsDark: isDark,
    initialFontSize: fontSize,
  ));
}

class MainApp extends StatefulWidget {
  final bool initialIsDark;
  final double initialFontSize;

  const MainApp({
    super.key,
    required this.initialIsDark,
    required this.initialFontSize,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late bool _isDarkMode;
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialIsDark;
    _fontSize = widget.initialFontSize;
  }

  void _updateTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _updateFontSize(double fontSize) {
    setState(() {
      _fontSize = fontSize;
    });
  }

  TextTheme _buildTextTheme(TextTheme baseTextTheme) {
    final double fontSizeDelta = _fontSize - 16.0;
    return baseTextTheme.copyWith(
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: (baseTextTheme.bodyLarge?.fontSize ?? 16.0) + fontSizeDelta),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: (baseTextTheme.bodyMedium?.fontSize ?? 14.0) + fontSizeDelta),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: (baseTextTheme.bodySmall?.fontSize ?? 12.0) + fontSizeDelta),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontSize: (baseTextTheme.titleLarge?.fontSize ?? 22.0) + fontSizeDelta),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: (baseTextTheme.titleMedium?.fontSize ?? 16.0) + fontSizeDelta),
      titleSmall: baseTextTheme.titleSmall?.copyWith(fontSize: (baseTextTheme.titleSmall?.fontSize ?? 14.0) + fontSizeDelta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseLightTheme = ThemeData.light();
    final baseDarkTheme = ThemeData.dark();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Note App',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: baseLightTheme.copyWith(
        primaryColor: Colors.blue,
        textTheme: _buildTextTheme(baseLightTheme.textTheme),
      ),
      darkTheme: baseDarkTheme.copyWith(
        primaryColor: Colors.blue,
        textTheme: _buildTextTheme(baseDarkTheme.textTheme),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate, 
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('vi', 'VN'),
      ],
      home: MainNavigation(
        isDarkMode: _isDarkMode,
        fontSize: _fontSize,
        onThemeChanged: _updateTheme,
        onFontSizeChanged: _updateFontSize,
      ),
    );
  }
}