import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/topics/topics_list_screen.dart';

// Class đại diện chung cho 1 item trong Thùng rác
class TrashItem {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isPrivate; // Phân biệt để khôi phục đúng vị trí
  final Topic? topic;

  TrashItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isPrivate,
    this.topic,
  });
}

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem> _trashItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrashItems();
  }

  // Tải danh sách ghi chú đã xóa từ cả 2 bảng
  Future<void> _loadTrashItems() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final topics = await db.getTopics();

    // Lấy Note thường trong thùng rác
    final normalNotes = await db.getTrashNotes(topics);
    // Lấy Note riêng tư trong thùng rác
    final privateNotes = await db.getTrashPrivateNotes();

    List<TrashItem> combinedList = [];

    for (var note in normalNotes) {
      combinedList.add(
        TrashItem(
          id: note.id,
          title: note.title,
          content: note.content,
          createdAt: note.createdAt,
          isPrivate: false,
          topic: note.topic,
        ),
      );
    }

    for (var note in privateNotes) {
      combinedList.add(
        TrashItem(
          id: note.id,
          title: note.title,
          content: note.content,
          createdAt: note.createdAt,
          isPrivate: true,
        ),
      );
    }

    // Sắp xếp theo thời gian mới nhất lên đầu
    combinedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _trashItems = combinedList;
      _isLoading = false;
    });
  }

  // Hàm trích xuất chữ thô từ Quill JSON
  String _formatContent(String rawContent) {
    if (rawContent.isEmpty) return 'Không có nội dung';
    try {
      final json = jsonDecode(rawContent);
      final doc = quill.Document.fromJson(json);
      final plainText = doc.toPlainText().trim();
      return plainText.isEmpty ? 'Không có nội dung' : plainText;
    } catch (_) {
      return rawContent;
    }
  }

  // Khôi phục về đúng vị trí (Thường hoặc Riêng tư)
  Future<void> _restoreItem(TrashItem item) async {
    if (item.isPrivate) {
      await DatabaseHelper.instance.restorePrivateNote(item.id);
    } else {
      await DatabaseHelper.instance.restoreNote(item.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã khôi phục "${item.title.isEmpty ? "Ghi chú" : item.title}" về danh sách ${item.isPrivate ? "Riêng tư" : "thường"}',
          ),
        ),
      );
    }
    _loadTrashItems();
  }

  // Xóa vĩnh viễn khỏi Database
  Future<void> _deletePermanently(TrashItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vĩnh viễn'),
        content: Text(
          'Ghi chú "${item.title.isEmpty ? "này" : item.title}" sẽ bị xóa hoàn toàn và không thể khôi phục!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa vĩnh viễn',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (item.isPrivate) {
        await DatabaseHelper.instance.deletePrivateNotePermanently(item.id);
      } else {
        await DatabaseHelper.instance.deleteNotePermanently(item.id);
      }
      _loadTrashItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thùng rác'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashItems.isEmpty
              ? const Center(
                  child: Text(
                    'Thùng rác rỗng',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _trashItems.length,
                  itemBuilder: (context, index) {
                    final item = _trashItems[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          item.isPrivate ? Icons.lock : Icons.note,
                          color: item.isPrivate
                              ? Colors.purple
                              : (item.topic?.color ?? Colors.grey),
                        ),
                        title: Text(
                          item.title.isEmpty ? 'Không có tiêu đề' : item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _formatContent(item.content),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nút Khôi phục
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.green),
                              tooltip: 'Khôi phục',
                              onPressed: () => _restoreItem(item),
                            ),
                            // Nút Xóa vĩnh viễn
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.red),
                              tooltip: 'Xóa vĩnh viễn',
                              onPressed: () => _deletePermanently(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}