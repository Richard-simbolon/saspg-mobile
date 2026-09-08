import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../theme/nocturne_theme.dart';

Future<void> _showServerSettingsDialog(BuildContext context) async {
  final auth = context.read<AuthState>();
  final ctrl = TextEditingController(text: auth.api.baseUrl);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: NocturneColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NocturneRadius.lg),
      ),
      title: const Text(
        'Pengaturan Server',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masukkan alamat IP server kantor. Cukup IP-nya saja (mis. 192.168.1.4) — port dan /api ditambahkan otomatis.',
            style: TextStyle(
              fontSize: 12,
              color: NocturneColors.textMuted(0.6),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: '192.168.1.4'),
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  if (saved == true && ctrl.text.trim().isNotEmpty) {
    await auth.setServerUrl(ctrl.text);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    final error = await auth.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NocturneColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  Icons.settings_ethernet,
                  color: NocturneColors.textMuted(0.55),
                ),
                tooltip: 'Pengaturan Server',
                onPressed: () => _showServerSettingsDialog(context),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: NocturneColors.accent),
                          borderRadius: BorderRadius.circular(
                            NocturneRadius.lg,
                          ),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          color: NocturneColors.accent,
                          size: 28,
                        ),
                      ),
                      const Text(
                        'One Big Circle (OBC)',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Masuk untuk mulai kunjungan hari ini',
                        style: TextStyle(
                          fontSize: 13,
                          color: NocturneColors.textMuted(0.6),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'NIK / Nomor Karyawan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xB2E9E9ED),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _usernameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'SPG-1000'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Kata Sandi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xB2E9E9ED),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                            ),
                            color: NocturneColors.textMuted(0.5),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: NocturneColors.danger,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: NocturneColors.accent,
                                  ),
                                )
                              : const Text('Masuk'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Lupa kata sandi? Hubungi supervisor Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: NocturneColors.textMuted(0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          context.watch<AuthState>().api.baseUrl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: NocturneColors.textMuted(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
