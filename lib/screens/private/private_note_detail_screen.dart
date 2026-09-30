import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/private/private_note_editor_screen.dart';

class PrivateNoteDetailScreen extends StatefulWidget {
  final NotePrivate note;

  const PrivateNoteDetailScreen({super.key, required this.note});

  @override
  State<PrivateNoteDetailScreen> createState() => _PrivateNoteDetailScreenState();
}

class _PrivateNoteDetailScreenState extends State<PrivateNoteDetailScreen> {
  late quill.QuillController _quillController;
  late NotePrivate _currentNote;

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
        readOnly: true,
      );
    } catch (_) {
      final doc = quill.Document()..insert(0, _currentNote.content);
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

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
        title: const Text('Ghi chú Riêng tư'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrivateNoteEditorScreen(note: _currentNote),
                ),
              );

              if (updated == true) {
                // Tải lại dữ liệu mới nhất từ DB
                final notes = await DatabaseHelper.instance.getPrivateNotes();
                final updatedNote = notes.firstWhere(
                  (n) => n.id == _currentNote.id,
                  orElse: () => _currentNote,
                );

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

            // Ngày tạo
            Row(
              children: [
                Icon(Icons.lock_clock, size: 16, color: Colors.purple.shade400),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),

            // Đính kèm Link Web (nếu có)
            if (_currentNote.webUrl != null && _currentNote.webUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _launchURL(_currentNote.webUrl!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentNote.webUrl!,
                          style: const TextStyle(
                            color: Colors.purple,
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

            // Danh sách Hình ảnh (nếu có)
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

            // Nội dung Rich Text
            quill.QuillEditor.basic(
              controller: _quillController,
            ),
          ],
        ),
      ),
    );
  }
}