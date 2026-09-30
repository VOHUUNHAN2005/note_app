import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/notes/note_editor_screen.dart'; // Đảm bảo import màn hình chỉnh sửa của bạn

class NoteDetailScreen extends StatefulWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late quill.QuillController _quillController;
  late Note _currentNote;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _initQuillController();
  }

  void _initQuillController() {
    try {
      final json = jsonDecode(_currentNote.content);
      _quillController = quill.QuillController(
        document: quill.Document.fromJson(json),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true, // Chế độ chỉ xem
      );
    } catch (_) {
      // Dự phòng nếu nội dung không phải định dạng JSON
      final doc = quill.Document()..insert(0, _currentNote.content);
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }
  void _copyContentToClipboard() {
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: plainText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép nội dung ghi chú!'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nội dung rỗng, không thể sao chép!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Mở liên kết web ngoài ứng dụng
  Future<void> _launchURL(String urlString) async {
    final Uri uri = Uri.parse(
      urlString.startsWith('http') ? urlString : 'https://$urlString',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy - HH:mm').format(_currentNote.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết ghi chú'),
        actions: [
          // Nút Chỉnh sửa ghi chú
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
            onPressed: () async {
              // Điều hướng sang màn hình chỉnh sửa và chờ kết quả cập nhật
              final updatedNote = await Navigator.push<Note>(
                context,
                MaterialPageRoute(
                  builder: (context) => NoteEditorScreen(note: _currentNote, topics: [],),
                ),
              );

              if (updatedNote != null) {
                setState(() {
                  _currentNote = updatedNote;
                  _initQuillController();
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề ghi chú
            Text(
              _currentNote.title.isEmpty ? 'Không có tiêu đề' : _currentNote.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Nhãn Chủ đề & Ngày tạo
            Row(
              children: [
                if (_currentNote.topic != null) ...[
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _currentNote.topic!.color,
                    ),
                    label: Text(
                      _currentNote.topic!.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: _currentNote.topic!.color.withOpacity(0.15),
                  ),
                  const SizedBox(width: 10),
                ],
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),

            // Đèn đính kèm Link Web (nếu có)
            if (_currentNote.webUrl != null && _currentNote.webUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _launchURL(_currentNote.webUrl!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentNote.webUrl!,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Danh sách Hình ảnh đính kèm (nếu có)
            if (_currentNote.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _currentNote.imagePaths.length,
                  itemBuilder: (context, index) {
                    final imagePath = _currentNote.imagePaths[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath),
                          height: 180,
                          width: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 140,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const Divider(height: 32, thickness: 1),

            Stack(
  children: [
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Theme(
        // Loại bỏ hoàn toàn màu bôi đen/highlight nền xanh lá
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Colors.transparent,
          ),
        ),
        child: quill.QuillEditor.basic(
          controller: _quillController,
        ),
      ),
    ),
    // Nút Copy góc trên phải ô nội dung
    Positioned(
      top: 20,
      right: 8,
      child: Tooltip(
        message: 'Sao chép nội dung',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _copyContentToClipboard,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.copy_outlined,
              size: 18,
              color: Colors.blueAccent,
            ),
          ),
        ),
      ),
    ),
  ],
)
          ],
        ),
      ),
    );
  }
}