import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ngekosin_brand.dart';

/// Hasil pengecekan username ke server (GET /auth/check-username).
enum _UsernameCheck { idle, checking, available, taken }

/// Form pendaftaran: nama, username, email, no. HP (opsional), kata sandi, peran.
/// Setelah sukses, pengguna langsung login dan router mengarahkan ke /home.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _usernameKey = GlobalKey<FormFieldState<String>>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  String _role = 'pencari'; // pencari | pemilik
  bool _hide = true;
  bool _loading = false;
  String? _error;

  _UsernameCheck _check = _UsernameCheck.idle;
  Timer? _debounce;

  // Aturan sama dengan server: 3-30 karakter huruf kecil/angka/titik/garis bawah,
  // tidak diawali/diakhiri simbol dan tanpa simbol ganda berurutan.
  static final _usernameRe = RegExp(r'^(?![._])(?!.*[._]{2})[a-z0-9._]{3,30}(?<![._])$');
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phoneRe = RegExp(r'^\+?[0-9]{8,15}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  /// Cek ke server setelah pengguna berhenti mengetik 0,5 detik.
  void _onUsernameChanged(String v) {
    _debounce?.cancel();
    if (!_usernameRe.hasMatch(v)) {
      setState(() => _check = _UsernameCheck.idle);
      return;
    }
    setState(() => _check = _UsernameCheck.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await AuthState.instance.isUsernameAvailable(v);
      if (!mounted || _username.text != v) return; // pengguna sudah mengetik lagi
      setState(() {
        _check = available == null
            ? _UsernameCheck.idle // gagal mengecek; server tetap memeriksa saat daftar
            : (available ? _UsernameCheck.available : _UsernameCheck.taken);
      });
      _usernameKey.currentState?.validate(); // hanya kolom username
    });
  }

  Widget? _usernameSuffix() {
    switch (_check) {
      case _UsernameCheck.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _UsernameCheck.available:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success);
      case _UsernameCheck.taken:
        return const Icon(Icons.cancel_rounded, color: AppColors.danger);
      case _UsernameCheck.idle:
        return null;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_check == _UsernameCheck.checking) {
      setState(() => _error = 'Tunggu sebentar, username sedang dicek.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AuthState.instance.register(
      name: _name.text.trim(),
      username: _username.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.replaceAll(RegExp(r'[\s-]'), ''),
      password: _pass.text,
      role: _role,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
      if (err != null && err.toLowerCase().contains('username')) {
        _check = _UsernameCheck.taken;
      }
    });
    if (err != null) _form.currentState?.validate();
    // sukses: AuthState berubah -> router redirect otomatis ke /home
  }

  void _toLogin() => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _toLogin,
        ),
      ),
      body: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: NgekosinWordmark(height: 44),
            ),
            const SizedBox(height: 24),
            Text('Buat akun baru', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text('Daftar gratis untuk menyimpan kos favorit, ajukan sewa, dan chat pemilik.',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),

            // ---- peran
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 'pencari', icon: Icon(Icons.search_rounded), label: Text('Cari kos')),
                ButtonSegment(
                    value: 'pemilik',
                    icon: Icon(Icons.home_work_outlined),
                    label: Text('Punya kos')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            if (_role == 'pemilik')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Kamu tetap masuk sebagai pencari kos dulu. Pengajuan pemilik kos '
                  'akan ditinjau admin.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 20),

            // ---- nama
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Nama wajib diisi';
                if (t.length < 2) return 'Nama minimal 2 karakter';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ---- username
            TextFormField(
              key: _usernameKey,
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              maxLength: 30,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                // selalu huruf kecil
                TextInputFormatter.withFunction(
                    (old, v) => v.copyWith(text: v.text.toLowerCase())),
              ],
              onChanged: _onUsernameChanged,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                counterText: '',
                helperText: 'Huruf kecil, angka, titik, atau garis bawah (3-30 karakter)',
                helperMaxLines: 2,
                suffixIcon: _usernameSuffix(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Username wajib diisi';
                if (!_usernameRe.hasMatch(t)) {
                  return t.length < 3
                      ? 'Username minimal 3 karakter'
                      : 'Hanya huruf kecil, angka, titik, garis bawah; '
                          'tidak diawali/diakhiri simbol';
                }
                if (_check == _UsernameCheck.taken) return 'Username sudah dipakai';
                return null;
              },
            ),
            if (_check == _UsernameCheck.available)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text('Username tersedia',
                    style: TextStyle(color: AppColors.success, fontSize: 12.5)),
              ),
            const SizedBox(height: 14),

            // ---- email
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Email wajib diisi';
                if (!_emailRe.hasMatch(t)) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ---- no. HP (opsional)
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
              decoration: const InputDecoration(
                labelText: 'No. HP (opsional)',
                hintText: '081234567890',
              ),
              validator: (v) {
                final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                if (t.isEmpty) return null;
                return _phoneRe.hasMatch(t) ? null : 'Nomor HP tidak valid';
              },
            ),
            const SizedBox(height: 14),

            // ---- kata sandi
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                helperText: 'Minimal 8 karakter',
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (v) {
                final t = v ?? '';
                if (t.isEmpty) return 'Kata sandi wajib diisi';
                if (t.length < 8) return 'Kata sandi minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass2,
              obscureText: _hide,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _loading ? null : _submit(),
              decoration: const InputDecoration(labelText: 'Ulangi kata sandi'),
              validator: (v) => v != _pass.text ? 'Kata sandi tidak sama' : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Daftar'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dengan mendaftar, kamu menyetujui syarat & ketentuan Ngekos.in. '
              'Dapatkan bonus 500 koin untuk akun baru!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _toLogin,
              child: const Text('Sudah punya akun? Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}
