import 'package:flutter/material.dart';
import 'package:note_app/services/security_service.dart';
import 'package:note_app/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final double fontSize;
  final Function(bool) onThemeChanged;
  final Function(double) onFontSizeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.fontSize,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDark;
  late double _fontSize;

  final _oldPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _fontSize = widget.fontSize;
  }

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog() async {
    final hasPassword = await SecurityService.instance.hasPassword();

    if (!hasPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chưa thiết lập mật khẩu riêng tư!')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đổi Mật Khẩu Riêng Tư'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _oldPwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu cũ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: OutlineInputBorder(),
                    ),
                    validator: SecurityService.instance.validateBankPassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val != _newPwdController.text) return 'Mật khẩu không khớp';
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
                  final isOldCorrect = await SecurityService.instance.verifyPassword(_oldPwdController.text);
                  if (!isOldCorrect) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mật khẩu hiện tại không chính xác!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }

                  await SecurityService.instance.savePassword(_newPwdController.text);
                  _oldPwdController.clear();
                  _newPwdController.clear();
                  _confirmPwdController.clear();

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đổi mật khẩu thành công!')),
                    );
                  }
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt Cá nhân'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Chế độ Tối (Dark Mode)'),
            subtitle: const Text('Thay đổi giao diện nền sáng / tối'),
            value: _isDark,
            onChanged: (value) async {
              setState(() {
                _isDark = value;
              });
              await SettingsService.setDarkMode(value);
              widget.onThemeChanged(value);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Kích thước phông chữ'),
            subtitle: Text('Kích thước hiện tại: ${_fontSize.toInt()}px'),
          ),
          Slider(
            value: _fontSize,
            min: 12.0,
            max: 24.0,
            divisions: 6,
            label: '${_fontSize.toInt()}px',
            onChanged: (value) async {
              setState(() {
                _fontSize = value;
              });
              await SettingsService.setFontSize(value);
              widget.onFontSizeChanged(value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.redAccent),
            title: const Text('Mật khẩu Riêng tư'),
            subtitle: const Text('Đổi mật khẩu khóa vùng bí mật'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }
}