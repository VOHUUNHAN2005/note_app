import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:note_app/database/db_helper.dart';

class PrivateNoteEditorScreen extends StatefulWidget {
  final NotePrivate? note;

  const PrivateNoteEditorScreen({super.key, this.note});

  @override
  State<PrivateNoteEditorScreen> createState() =>
      _PrivateNoteEditorScreenState();
}

class _PrivateNoteEditorScreenState extends State<PrivateNoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _webUrlController = TextEditingController();

  late quill.QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();

  List<String> _imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();

    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _webUrlController.text = widget.note!.webUrl ?? '';
      _imagePaths = List.from(widget.note!.imagePaths);

      if (widget.note!.content.isNotEmpty) {
        try {
          final jsonDelta = jsonDecode(widget.note!.content);
          _quillController.document = quill.Document.fromJson(jsonDelta);
        } catch (_) {
          _quillController.document = quill.Document()
            ..insert(0, widget.note!.content);
        }
      }
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _editorFocusNode.dispose();
    _titleController.dispose();
    _webUrlController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    if (url.trim().isEmpty) return true;
    final urlPattern = r'^(http|https):\/\/[^" \n]+$';
    return RegExp(urlPattern, caseSensitive: false).hasMatch(url.trim());
  }

  Future<String> _saveImageToAppDirectory(String originalPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'private_${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalPath)}';
    final savedImage = await File(
      originalPath,
    ).copy('${directory.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final localImagePath = await _saveImageToAppDirectory(pickedFile.path);
      setState(() {
        _imagePaths.add(localImagePath);
      });
    }
  }

  Future<void> _savePrivateNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final content = jsonEncode(_quillController.document.toDelta().toJson());
    final plainTextContent = _quillController.document.toPlainText().trim();
    final webUrl = _webUrlController.text.trim().isEmpty
        ? null
        : _webUrlController.text.trim();

    if (plainTextContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung ghi chú không được để trống!')),
      );
      return;
    }

    if (widget.note == null) {
      final newNote = NotePrivate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        imagePaths: _imagePaths,
        webUrl: webUrl,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertPrivateNote(newNote);
    } else {
      widget.note!.title = title;
      widget.note!.content = content;
      widget.note!.imagePaths = _imagePaths;
      widget.note!.webUrl = webUrl;
      widget.note!.createdAt = DateTime.now();

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
          widget.note == null
              ? 'Thêm Ghi chú Riêng tư'
              : 'Sửa Ghi chú Riêng tư',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề Ghi chú
              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề ghi chú bí mật *',
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tiêu đề không được để trống';
                  }
                  return null;
                },
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Đường dẫn Web URL
              TextFormField(
                controller: _webUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Đường dẫn Web (Tùy chọn)',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      !_isValidUrl(value)) {
                    return 'Đường dẫn URL không hợp lệ!';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quill Toolbar (Thanh công cụ định dạng Rich Text)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: quill.QuillSimpleToolbar(
                  controller: _quillController,
                  config: const quill.QuillSimpleToolbarConfig(
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showListBullets: true,
                    showListNumbers: true,
                    showFontFamily: false,
                    showFontSize: false,
                    showHeaderStyle: false,
                    showAlignmentButtons: false,
                    showDirection: false,
                    showListCheck: false,
                    showCodeBlock: false,
                    showInlineCode: false,
                    showQuote: false,
                    showIndent: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: false,
                    showStrikeThrough: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showLink: false,
                    showSearchButton: false,
                    showClipboardCut: false,
                    showClipboardCopy: false,
                    showClipboardPaste: false,
                    showUndo: false,
                    showRedo: false,
                  ),
                ),
              ),

              // Quill Editor (Vùng nhập nội dung)
              Container(
                height: 300,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: quill.QuillEditor(
                  controller: _quillController,
                  focusNode: _editorFocusNode,
                  scrollController: ScrollController(),
                  config: const quill.QuillEditorConfig(
                    placeholder: 'Nhập nội dung bí mật...',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hình ảnh đính kèm
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hình ảnh đính kèm (Tùy chọn):',
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
                      'Chưa có ảnh nào được đính kèm.',
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
              const SizedBox(height: 24),

              // Nút Lưu Ghi chú
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _savePrivateNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Lưu Ghi chú Riêng tư',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
