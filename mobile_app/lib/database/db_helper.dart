import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/photo_record.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('photocraft.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (kIsWeb) {
      dbPath = filePath;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docDir.path, filePath);
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        original_path TEXT,
        edited_path TEXT NOT NULL,
        filter_applied TEXT DEFAULT 'Gốc',
        sharpen_applied TEXT DEFAULT 'Không',
        note TEXT DEFAULT '',
        rating INTEGER DEFAULT 5,
        is_favorite INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertPhoto(PhotoRecord photo) async {
    final db = await database;
    final id = await db.insert('photos', photo.toMap());
    return id;
  }

  Future<int> updatePhoto(PhotoRecord photo) async {
    final db = await database;
    return await db.update(
      'photos',
      photo.toMap(),
      where: 'id = ?',
      whereArgs: [photo.id],
    );
  }

  Future<int> toggleFavorite(int id, bool currentStatus) async {
    final db = await database;
    return await db.update(
      'photos',
      {'is_favorite': currentStatus ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePhoto(int id) async {
    final db = await database;
    return await db.delete(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PhotoRecord>> getAllPhotos({String? query}) async {
    final db = await database;
    List<Map<String, dynamic>> results;
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      results = await db.query(
        'photos',
        where: 'title LIKE ? OR filter_applied LIKE ? OR sharpen_applied LIKE ? OR note LIKE ?',
        whereArgs: [q, q, q, q],
        orderBy: 'id DESC',
      );
    } else {
      results = await db.query('photos', orderBy: 'id DESC');
    }
    return results.map((m) => PhotoRecord.fromMap(m)).toList();
  }

  Future<List<PhotoRecord>> getRecentPhotos({int limit = 5}) async {
    final db = await database;
    final results = await db.query('photos', orderBy: 'id DESC', limit: limit);
    return results.map((m) => PhotoRecord.fromMap(m)).toList();
  }

  Future<List<PhotoRecord>> getFavoritePhotos() async {
    final db = await database;
    final results = await db.query(
      'photos',
      where: 'is_favorite = 1',
      orderBy: 'id DESC',
    );
    return results.map((m) => PhotoRecord.fromMap(m)).toList();
  }

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM photos'),
        ) ?? 0;
    final favorites = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM photos WHERE is_favorite = 1'),
        ) ?? 0;
    final diaries = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM photos WHERE note IS NOT NULL AND note != ''"),
        ) ?? 0;
    return {
      'total': total,
      'favorites': favorites,
      'diaries': diaries,
    };
  }

  Future<void> seedInitialDataIfEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM photos')) ?? 0;
    if (count > 0) return;

    // Copy sample assets into documents directory if mobile/desktop
    String path1 = 'assets/samples/sunset.jpg';
    String path2 = 'assets/samples/portrait.jpg';
    String path3 = 'assets/samples/night_city.jpg';

    if (!kIsWeb) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        
        final f1 = File(p.join(docDir.path, 'sample_sunset.jpg'));
        if (!await f1.exists()) {
          final b1 = await rootBundle.load(path1);
          await f1.writeAsBytes(b1.buffer.asUint8List());
        }
        path1 = f1.path;

        final f2 = File(p.join(docDir.path, 'sample_portrait.jpg'));
        if (!await f2.exists()) {
          final b2 = await rootBundle.load(path2);
          await f2.writeAsBytes(b2.buffer.asUint8List());
        }
        path2 = f2.path;

        final f3 = File(p.join(docDir.path, 'sample_night_city.jpg'));
        if (!await f3.exists()) {
          final b3 = await rootBundle.load(path3);
          await f3.writeAsBytes(b3.buffer.asUint8List());
        }
        path3 = f3.path;
      } catch (e) {
        debugPrint('Note during seed asset extraction: $e');
      }
    }

    // Insert the 3 items matching the wireframes
    await insertPhoto(PhotoRecord(
      title: 'Hoàng hôn ven biển',
      editedPath: path1,
      originalPath: path1,
      filterApplied: 'Vintage',
      sharpenApplied: 'USM',
      note: 'Ảnh chụp tại biển Đà Nẵng, đã tăng độ nét chi tiết và chỉnh tông màu ấm áp vintage.',
      rating: 5,
      isFavorite: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ));

    await insertPhoto(PhotoRecord(
      title: 'Chân dung nghệ thuật',
      editedPath: path2,
      originalPath: path2,
      filterApplied: 'Trắng đen',
      sharpenApplied: 'Kernel 3x3',
      note: 'Chuyển đổi sang trắng đen để làm nổi bật cảm xúc và bóng đổ khuôn mặt.',
      rating: 5,
      isFavorite: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ));

    await insertPhoto(PhotoRecord(
      title: 'Phố đêm rực rỡ',
      editedPath: path3,
      originalPath: path3,
      filterApplied: 'vivi HDR',
      sharpenApplied: 'CLAHE Contrast',
      note: 'Ảnh chụp phố đêm rực rỡ sắc màu, tăng tương phản và chi tiết ánh sáng lung linh.',
      rating: 5,
      isFavorite: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ));
  }
}
