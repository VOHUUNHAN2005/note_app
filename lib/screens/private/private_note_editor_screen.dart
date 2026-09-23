import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:note_app/database/db_helper.dart';

class PrivateNoteEditorScreen extends StatefulWidget {
  final NotePrivate? note;

  const PrivateNoteEditorScreen({
    super.key,
    this.note,
  });

  @override
  State<PrivateNoteEditorScreen> createState() => _PrivateNoteEditorScreenState();
}

class _PrivateNoteEditorScreenState extends State<PrivateNoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _webUrlController = TextEditingController();

  List<String> _imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _webUrlController.text = widget.note!.webUrl ?? '';
      _imagePaths = List.from(widget.note!.imagePaths);
    }
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  Future<String> _saveImageToAppDirectory(String originalPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'private_${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalPath)}';
    final savedImage = await File(originalPath).copy('${directory.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final localImagePath = await _saveImageToAppDirectory(pickedFile.path);
      setState(() {
        _imagePaths.add(localImagePath);
      });
    }
  }

  Future<void> _savePrivateNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final url = _webUrlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề ghi chú!')),
      );
      return;
    }

    if (url.isNotEmpty && !_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đường dẫn URL không hợp lệ (cần bắt đầu bằng http:// hoặc https://)!')),
      );
      return;
    }

    if (widget.note == null) {
      final newNote = NotePrivate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        imagePaths: _imagePaths,
        webUrl: url.isEmpty ? null : url,
      );
      await DatabaseHelper.instance.insertPrivateNote(newNote);
    } else {
      widget.note!.title = title;
      widget.note!.content = content;
      widget.note!.imagePaths = _imagePaths;
      widget.note!.webUrl = url.isEmpty ? null : url;

      await DatabaseHelper.instance.updatePrivateNote(widget.note!);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.note == null ? 'Thêm Ghi chú Riêng tư' : 'Sửa Ghi chú Riêng tư',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _savePrivateNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Tiêu đề ghi chú bí mật',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextField(
              controller: _webUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Đường dẫn Web (URL)',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 15, 
              minLines: 5,  
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Nhập nội dung bí mật...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hình ảnh đính kèm:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Thêm ảnh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _imagePaths.isEmpty
                ? const Text(
                    'Chưa có ảnh đính kèm.',
                    style: TextStyle(color: Colors.grey),
                  )
                : SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagePaths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(_imagePaths[index])),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _imagePaths.removeAt(index);
                                  });
                                },
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            
                          ],
                        );
                      },
                      
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}