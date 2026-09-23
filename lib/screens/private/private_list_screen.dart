import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/private/private_note_editor_screen.dart';
import 'package:note_app/services/security_service.dart';

class PrivateListScreen extends StatefulWidget {
  const PrivateListScreen({super.key});

  @override
  State<PrivateListScreen> createState() => _PrivateListScreenState();
}

class _PrivateListScreenState extends State<PrivateListScreen>
    with WidgetsBindingObserver {
  List<NotePrivate> _privateNotes = [];
  bool _isAuthenticated = false;
  bool _hasPassword = false;
  bool _isLoading = true;

  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPasswordSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _isAuthenticated = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lockApp();
    }
  }

  void _lockApp() {
    if (mounted) {
      setState(() {
        _isAuthenticated = false;
        _passwordController.clear();
      });
    }
  }

  Future<void> _checkPasswordSetup() async {
    setState(() => _isLoading = true);
    final hasPwd = await SecurityService.instance.hasPassword();
    setState(() {
      _hasPassword = hasPwd;
      _isLoading = false;
    });
  }

  Future<void> _loadPrivateNotes() async {
    setState(() => _isLoading = true);
    final loadedNotes = await DatabaseHelper.instance.getPrivateNotes();
    setState(() {
      _privateNotes = loadedNotes;
      _isLoading = false;
    });
  }

  Future<void> _verifyPassword() async {
    final inputPwd = _passwordController.text.trim();
    final isValid = await SecurityService.instance.verifyPassword(inputPwd);

    if (isValid) {
      setState(() {
        _isAuthenticated = true;
      });
      _loadPrivateNotes();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mật khẩu không đúng! Vui lòng thử lại.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showCreatePasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thiết lập Mật khẩu Riêng tư'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: OutlineInputBorder(),
                    ),
                    validator: SecurityService.instance.validateBankPassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val != _newPasswordController.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await SecurityService.instance.savePassword(
                    _newPasswordController.text,
                  );
                  _newPasswordController.clear();
                  _confirmPasswordController.clear();

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tạo mật khẩu thành công!')),
                    );
                    setState(() {
                      _hasPassword = true;
                      _isAuthenticated = true;
                    });
                    _loadPrivateNotes();
                  }
                }
              },
              child: const Text('Lưu & Mở Khóa'),
            ),
          ],
        );
      },
    );
  }

  String _formatContent(String content) {
    if (content.length <= 20) return content;
    return '${content.substring(0, 20)}...';
  }

  void _deletePrivateNote(String id) async {
    await DatabaseHelper.instance.deletePrivateNote(id);
    _loadPrivateNotes();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPassword) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ghi chú Riêng tư')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Chưa thiết lập mật khẩu bảo mật',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bạn cần tạo mật khẩu bảo vệ trước khi sử dụng tính năng Ghi chú Riêng tư.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showCreatePasswordDialog,
                  icon: const Icon(Icons.security),
                  label: const Text('Tạo Mật Khẩu Ngay'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mở khóa Ghi chú Riêng tư')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'Khu vực Khóa Bảo Mật',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng nhập mật khẩu của bạn để xem ghi chú riêng tư.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _verifyPassword(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _verifyPassword,
                    child: const Text(
                      'Mở Khóa',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ghi chú Riêng tư')),
      body: _privateNotes.isEmpty
          ? const Center(
              child: Text(
                'Chưa có ghi chú riêng tư nào.\nBấm + để thêm ghi chú bí mật!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _privateNotes.length,
              itemBuilder: (context, index) {
                final note = _privateNotes[index];
                final formattedDate = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(note.createdAt);

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                note.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deletePrivateNote(note.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatContent(note.content),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tạo lúc: $formattedDate',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            IconButton(
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PrivateNoteEditorScreen(note: note),
                                  ),
                                );
                                if (updated == true) {
                                  _loadPrivateNotes();
                                }
                              },
                              icon: Icon(Icons.edit, color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrivateNoteEditorScreen(),
            ),
          );
          if (added == true) {
            _loadPrivateNotes();
          }
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
