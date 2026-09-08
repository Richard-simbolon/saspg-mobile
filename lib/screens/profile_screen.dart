import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/image_provider.dart';
import '../widgets/nocturne_card.dart';

const _genderLabel = {'L': 'Laki-laki', 'P': 'Perempuan'};
const _leaveStatusLabel = {
  'aktif': 'Aktif',
  'cuti': 'Cuti',
  'resign': 'Resign',
  'dipecat': 'Diberhentikan',
  'banned': 'Banned',
  'block': 'Diblokir',
};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusCtrl = TextEditingController();
  bool _editingStatus = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _statusCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    final auth = context.read<AuthState>();
    final spgId = auth.user?.spgId;
    if (spgId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await auth.api.updateStatusNote(spgId, _statusCtrl.text.trim());
      await auth.refreshSpgProfile();
      if (mounted) setState(() => _editingStatus = false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final spg = auth.spgProfile;
    final user = auth.user;

    if (spg == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final photo = resolveImageProvider(spg.photoUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya', style: TextStyle(fontSize: 16))),
      body: RefreshIndicator(
        onRefresh: auth.refreshSpgProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NocturneColors.surface,
                      border: Border.all(color: NocturneColors.divider),
                      image: photo != null ? DecorationImage(image: photo, fit: BoxFit.cover) : null,
                    ),
                    child: photo == null ? Icon(Icons.person_outline, size: 40, color: NocturneColors.textMuted(0.4)) : null,
                  ),
                  const SizedBox(height: 10),
                  Text(spg.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    [if (spg.brandName != null) spg.brandName!, spg.region].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.55)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            NocturneCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CardKicker('Status'),
                      if (!_editingStatus)
                        GestureDetector(
                          onTap: () {
                            _statusCtrl.text = spg.statusNote ?? '';
                            setState(() => _editingStatus = true);
                          },
                          child: Icon(Icons.edit_outlined, size: 15, color: NocturneColors.accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_editingStatus) ...[
                    TextField(
                      controller: _statusCtrl,
                      maxLength: 200,
                      maxLines: 2,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'mis. Sedang cuti sampai 20 Agustus, Ditugaskan ke outlet lain…',
                        isDense: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(_error!, style: TextStyle(color: NocturneColors.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => setState(() => _editingStatus = false),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed: _saving ? null : _saveStatus,
                          child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                        ),
                      ],
                    ),
                  ] else if (spg.statusNote != null && spg.statusNote!.isNotEmpty) ...[
                    Text(spg.statusNote!, style: const TextStyle(fontSize: 13.5)),
                    if (spg.statusNoteUpdatedAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Diperbarui ${_formatDateTime(spg.statusNoteUpdatedAt!)}',
                        style: TextStyle(fontSize: 10.5, color: NocturneColors.textMuted(0.45)),
                      ),
                    ],
                  ] else
                    Text(
                      'Belum ada status — ketuk ikon pensil untuk menambahkan (mis. sedang cuti, ditugaskan ke lokasi lain).',
                      style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.5)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            NocturneCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardKicker('Tentang'),
                  const SizedBox(height: 8),
                  _InfoRow('NIK', spg.nik),
                  _InfoRow('Jenis Kelamin', spg.gender != null ? _genderLabel[spg.gender] : null),
                  _InfoRow('Tempat, Tanggal Lahir', _birthLabel(spg.birthPlace, spg.birthDate)),
                  _InfoRow('Status Pernikahan', spg.maritalStatus),
                  _InfoRow('Pendidikan', spg.education),
                ],
              ),
            ),
            const SizedBox(height: 14),

            NocturneCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardKicker('Kontak'),
                  const SizedBox(height: 8),
                  _InfoRow('Telepon', spg.contact),
                  _InfoRow('Email', spg.email),
                  _InfoRow('Alamat', spg.address),
                ],
              ),
            ),
            const SizedBox(height: 14),

            NocturneCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardKicker('Info Kerja'),
                  const SizedBox(height: 8),
                  _InfoRow('Brand', spg.brandName),
                  _InfoRow('Kontrak', spg.contract),
                  _InfoRow('Status Kepegawaian', spg.leaveStatus != null ? _leaveStatusLabel[spg.leaveStatus] : null),
                  _InfoRow('Bergabung Sejak', spg.joinDate),
                  _InfoRow('Username Login', user.username),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _birthLabel(String? place, String? date) {
    if (place == null && date == null) return null;
    return [if (place != null) place, if (date != null) date].join(', ');
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} $h:$min';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.55))),
          ),
          Expanded(
            child: Text(
              (value == null || value!.isEmpty) ? '-' : value!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
