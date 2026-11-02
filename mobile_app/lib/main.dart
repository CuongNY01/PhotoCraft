import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/db_helper.dart';
import 'models/photo_record.dart';
import 'screens/editor_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Desktop / Windows test harness
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize API service and auto-discover server on current Wi-Fi network
  await ApiService.instance.init();

  // Pre-seed sample data
  try {
    await DBHelper.instance.seedInitialDataIfEmpty();
  } catch (e) {
    debugPrint('Init DB error: $e');
  }

  runApp(const PhotoCraftApp());
}

class PhotoCraftApp extends StatelessWidget {
  const PhotoCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Active photo for Editor
  Uint8List? _editorImageBytes;
  String _editorTitle = 'Hoàng hôn ven biển';
  PhotoRecord? _editorRecord;

  // Key to force refresh history / favorites
  int _refreshKey = 0;

  void _openEditorWithImage(Uint8List bytes, String title, PhotoRecord? record) {
    setState(() {
      _editorImageBytes = bytes;
      _editorTitle = title;
      _editorRecord = record;
      _currentIndex = 1; // Switch to Editor tab
    });
  }

  void _notifyDataChanged() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: Trang chủ (Home)
          HomeScreen(
            key: ValueKey('home_$_refreshKey'),
            onOpenEditor: _openEditorWithImage,
            onOpenHistory: () => setState(() => _currentIndex = 2),
            onOpenFavorites: () => setState(() => _currentIndex = 3),
          ),

          // 1: Biên tập (Editor)
          EditorScreen(
            key: ValueKey('editor_${_editorTitle}_${_editorImageBytes?.length}'),
            initialImageBytes: _editorImageBytes,
            title: _editorTitle,
            existingRecord: _editorRecord,
            onSaved: () {
              _notifyDataChanged();
              setState(() => _currentIndex = 2); // Go to History to see saved photo
            },
          ),

          // 2: Lịch sử (History)
          HistoryScreen(
            key: ValueKey('history_$_refreshKey'),
            onContinueEdit: (bytes, title, record) {
              _openEditorWithImage(bytes, title, record);
            },
          ),

          // 3: Yêu thích (Favorites)
          FavoritesScreen(
            key: ValueKey('favorites_$_refreshKey'),
            onOpenPhoto: (bytes, title, record) {
              _openEditorWithImage(bytes, title, record);
            },
          ),

          // 4: Cài đặt (Settings)
          SettingsScreen(
            key: ValueKey('settings_$_refreshKey'),
            onDataChanged: _notifyDataChanged,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Biên tập',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            activeIcon: Icon(Icons.access_time_filled),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite, color: AppTheme.accentPink),
            label: 'Yêu thích',
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
