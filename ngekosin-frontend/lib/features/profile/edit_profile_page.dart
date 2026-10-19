import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';

/// Ubah nama & nomor HP, serta ganti password.
/// Email tidak bisa diubah (dipakai untuk login).
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _profileKey = GlobalKey<FormState>();
  final _pwKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: AuthState.instance.user?.name);
  late final _phone = TextEditingController(text: AuthState.instance.user?.phone);
  final _oldPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();

  bool _savingProfile = false;
  bool _savingPw = false;
  bool _showPw = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _oldPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingProfile = true);
    final phone = _phone.text.trim();
    final err = await AuthState.instance.updateProfile(
      name: _name.text.trim(),
      phone: phone.isEmpty ? null : phone,
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);
    if (err != null) {
      _toast(err, error: true);
      return;
    }
    _toast('Profil berhasil diperbarui');
    context.pop();
  }

  Future<void> _savePassword() async {
    if (!_pwKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingPw = true);
    final err = await AuthState.instance.changePassword(_oldPw.text, _newPw.text);
    if (!mounted) return;
    setState(() => _savingPw = false);
    if (err != null) {
      _toast(err, error: true);
      return;
    }
    _oldPw.clear();
    _newPw.clear();
    _confirmPw.clear();
    _toast('Password berhasil diganti');
  }

  String? _validatePhone(String? v) {
    final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (t.isEmpty) return null; // opsional
    if (!RegExp(r'^(\+62|62|0)8[0-9]{8,11}$').hasMatch(t)) {
      return 'Nomor HP tidak valid (contoh: 081234567890)';
    }
    return null;
  }

  Widget _pwField(String label, TextEditingController c, String? Function(String?) v) {
    return TextFormField(
      controller: c,
      obscureText: !_showPw,
      validator: v,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.instance.user;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah profil')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.marigold,
                child: Text(
                  (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _profileKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama lengkap'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Nama wajib diisi';
                      if (t.length < 3) return 'Nama minimal 3 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: user?.username ?? '',
                    readOnly: true,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      helperText: 'Username tidak dapat diubah',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: user?.email ?? '',
                    readOnly: true,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: 'Email tidak dapat diubah',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP (opsional)',
                      hintText: '081234567890',
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _savingProfile ? null : _saveProfile,
                    child: _savingProfile
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan perubahan'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Ganti password', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _pwKey,
              child: Column(
                children: [
                  _pwField('Password lama', _oldPw,
                      (v) => (v ?? '').isEmpty ? 'Password lama wajib diisi' : null),
                  const SizedBox(height: 14),
                  _pwField('Password baru', _newPw, (v) {
                    if ((v ?? '').length < 6) return 'Minimal 6 karakter';
                    if (v == _oldPw.text) return 'Password baru harus berbeda dari yang lama';
                    return null;
                  }),
                  const SizedBox(height: 14),
                  _pwField('Ulangi password baru', _confirmPw,
                      (v) => v != _newPw.text ? 'Password tidak sama' : null),
                  CheckboxListTile(
                    value: _showPw,
                    onChanged: (v) => setState(() => _showPw = v ?? false),
                    title: const Text('Tampilkan password'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _savingPw ? null : _savePassword,
                    child: _savingPw
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Perbarui password'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
