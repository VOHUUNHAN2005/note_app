import 'package:flutter/material.dart';
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/notes/notes_list_screen.dart';
import 'package:note_app/screens/private/private_list_screen.dart';
import 'package:note_app/screens/settings/settting_screen.dart';
import 'package:note_app/screens/topics/topics_list_screen.dart';

class MainNavigation extends StatefulWidget {
  final bool isDarkMode;
  final double fontSize;
  final Function(bool) onThemeChanged;
  final Function(double) onFontSizeChanged;

  const MainNavigation({
    super.key,
    required this.isDarkMode,
    required this.fontSize,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  List<Topic> _globalTopics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }
  Future<void> _loadDataFromDatabase() async {
    final topics = await DatabaseHelper.instance.readAllTopics();
    setState(() {
      _globalTopics = topics;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      NotesListScreen(topics: _globalTopics),
      TopicsListScreen(topics: _globalTopics),
      const PrivateListScreen(),
      SettingsScreen(
        isDarkMode: widget.isDarkMode,
        fontSize: widget.fontSize,
        onThemeChanged: widget.onThemeChanged,
        onFontSizeChanged: widget.onFontSizeChanged,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.note_alt_outlined),
            activeIcon: Icon(Icons.note_alt),
            label: 'Ghi chú',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Chủ đề',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline),
            activeIcon: Icon(Icons.lock),
            label: 'Riêng tư',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}