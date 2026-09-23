import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:note_app/screens/topics/topics_list_screen.dart';
import 'package:note_app/services/security_service.dart';

// ==========================================
// 1. CLASS NOTE THƯỜNG (GIỮ NGUYÊN GỐC 100%)
// ==========================================
class Note {
  String id;
  String title;
  String content;
  Topic? topic;
  List<String> imagePaths;
  String? webUrl;
  DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.topic,
    this.imagePaths = const [],
    this.webUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'topic_id': topic?.id,
      'image_paths': imagePaths.join(','),
      'web_url': webUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, List<Topic> topics) {
    Topic? matchedTopic;
    if (map['topic_id'] != null) {
      try {
        matchedTopic = topics.firstWhere((t) => t.id == map['topic_id']);
      } catch (_) {
        matchedTopic = null;
      }
    }

    String pathsStr = map['image_paths'] ?? '';
    List<String> images = pathsStr.isNotEmpty ? pathsStr.split(',') : [];

    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      topic: matchedTopic,
      imagePaths: images,
      webUrl: map['web_url'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}

// ==========================================
// 2. CLASS NOTE PRIVATE (TÁCH RIÊNG HOÀN TOÀN)
// ==========================================
class NotePrivate {
  String id;
  String title;
  String content;
  List<String> imagePaths;
  String? webUrl;
  DateTime createdAt;

  NotePrivate({
    required this.id,
    required this.title,
    required this.content,
    this.imagePaths = const [],
    this.webUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Chuyển sang Map để lưu vào SQLite (Tự động MÃ HÓA nội dung)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': SecurityService.instance.encryptText(content), // Mã hóa AES-256
      'image_paths': imagePaths.join(','),
      'web_url': webUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Chuyển từ Map SQLite sang Object (Tự động GIẢI MÃ nội dung)
  factory NotePrivate.fromMap(Map<String, dynamic> map) {
    String pathsStr = map['image_paths'] ?? '';
    List<String> images = pathsStr.isNotEmpty ? pathsStr.split(',') : [];
    String rawContent = map['content'] ?? '';

    return NotePrivate(
      id: map['id'],
      title: map['title'],
      content: SecurityService.instance.decryptText(rawContent), // Giải mã AES-256
      imagePaths: images,
      webUrl: map['web_url'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}

// ==========================================
// 3. DATABASE HELPER
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Nâng version lên 3 để tạo thêm bảng private_notes
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notes ADD COLUMN created_at TEXT');
        }
        if (oldVersion < 3) {
          // Tạo thêm bảng riêng biệt cho Ghi chú Riêng tư
          await db.execute('''
            CREATE TABLE private_notes (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              image_paths TEXT,
              web_url TEXT,
              created_at TEXT
            )
          ''');
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // Bảng Topics
    await db.execute('''
      CREATE TABLE topics (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');

    // Bảng Notes Thường
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        topic_id TEXT,
        image_paths TEXT,
        web_url TEXT,
        created_at TEXT,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE SET NULL
      )
    ''');

    // Bảng Notes Riêng tư
    await db.execute('''
      CREATE TABLE private_notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        image_paths TEXT,
        web_url TEXT,
        created_at TEXT
      )
    ''');
  }

  // --- CRUD TOPICS (GIỮ NGUYÊN GỐC) ---
  Future<int> insertTopic(Topic topic) async {
    final db = await instance.database;
    return await db.insert('topics', topic.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Topic>> readAllTopics() async {
    final db = await instance.database;
    final result = await db.query('topics');
    return result.map((json) => Topic.fromMap(json)).toList();
  }

  Future<List<Topic>> getTopics() async => await readAllTopics();

  Future<int> deleteTopic(String id) async {
    final db = await instance.database;
    return await db.delete('topics', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD NOTES THƯỜNG (GIỮ NGUYÊN GỐC) ---
  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    return await db.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Note>> getNotes(List<Topic> topics) async {
    final db = await instance.database;
    final result = await db.query('notes', orderBy: 'created_at DESC');
    return result.map((json) => Note.fromMap(json, topics)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    return await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(String id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD NOTES RIÊNG TƯ (MỚI) ---
  Future<int> insertPrivateNote(NotePrivate note) async {
    final db = await instance.database;
    return await db.insert('private_notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NotePrivate>> getPrivateNotes() async {
    final db = await instance.database;
    final result = await db.query('private_notes', orderBy: 'created_at DESC');
    return result.map((json) => NotePrivate.fromMap(json)).toList();
  }

  Future<int> updatePrivateNote(NotePrivate note) async {
    final db = await instance.database;
    return await db.update('private_notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deletePrivateNote(String id) async {
    final db = await instance.database;
    return await db.delete('private_notes', where: 'id = ?', whereArgs: [id]);
  }
}