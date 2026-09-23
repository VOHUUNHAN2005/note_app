import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/topics/topics_list_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final List<Topic> topics;

  const NoteEditorScreen({super.key, this.note, required this.topics});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _webUrlController = TextEditingController();

  late quill.QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();

  Topic? _selectedTopic;
  List<String> _imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.amber,
    Colors.purple,
    Colors.teal,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();

    _quillController = quill.QuillController.basic();

    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _webUrlController.text = widget.note!.webUrl ?? '';
      _selectedTopic = widget.note!.topic;
      _imagePaths = List.from(widget.note!.imagePaths);

      if (widget.note!.content.isNotEmpty) {
        _quillController.document = quill.Document()
          ..insert(0, widget.note!.content);
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

  void _showAddTopicDialog() {
    final nameController = TextEditingController();
    Color selectedColor = _availableColors[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm chủ đề mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên chủ đề *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Màu đại diện:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _availableColors.map((color) {
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final newTopic = Topic(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      color: selectedColor,
                    );

                    await DatabaseHelper.instance.insertTopic(newTopic);

                    setState(() {
                      widget.topics.add(newTopic);
                      _selectedTopic = newTopic;
                    });

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _saveImageToAppDirectory(String originalPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalPath)}';
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
      setState(() => _imagePaths.add(localImagePath));
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc thêm Chủ đề!')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final content = _quillController.document.toPlainText().trim();
    final webUrl = _webUrlController.text.trim().isEmpty
        ? null
        : _webUrlController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung ghi chú không được để trống!')),
      );
      return;
    }

    if (widget.note == null) {
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        topic: _selectedTopic,
        imagePaths: _imagePaths,
        webUrl: webUrl,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertNote(newNote);
    } else {
      widget.note!.title = title;
      widget.note!.content = content;
      widget.note!.topic = _selectedTopic;
      widget.note!.imagePaths = _imagePaths;
      widget.note!.webUrl = webUrl;
      widget.note!.createdAt = DateTime.now();

      await DatabaseHelper.instance.updateNote(widget.note!);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Thêm Ghi chú' : 'Sửa Ghi chú'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề ghi chú *',
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Topic>(
                      value: _selectedTopic,
                      hint: const Text('Chọn chủ đề *'),
                      items: widget.topics.map((topic) {
                        return DropdownMenuItem<Topic>(
                          value: topic,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: topic.color,
                                radius: 8,
                              ),
                              const SizedBox(width: 8),
                              Text(topic.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedTopic = value),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null) return 'Vui lòng chọn chủ đề';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _showAddTopicDialog,
                    icon: const Icon(Icons.add),
                    tooltip: 'Thêm chủ đề mới',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _webUrlController,
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
                    placeholder: 'Nhập nội dung ghi chú...',
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                                  onTap: () => setState(
                                    () => _imagePaths.removeAt(index),
                                  ),
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

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Lưu Ghi chú',
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
