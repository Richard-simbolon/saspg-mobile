import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/image_provider.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';

const _typeLabels = {
  'tahunan': 'Cuti Tahunan',
  'sakit': 'Sakit',
  'izin': 'Izin',
  'lainnya': 'Lainnya',
};

/// Label for the attachment picker — only `sakit` and `izin` get one, matching
/// what's actually required in practice (a surat sakit / supporting document).
const _attachmentLabels = {
  'sakit': 'Surat Keterangan Sakit',
  'izin': 'Dokumen Pendukung',
};

const _statusLabels = {
  'pending': 'Menunggu',
  'approved': 'Disetujui',
  'rejected': 'Ditolak',
};

TagVariant _statusVariant(String status) {
  switch (status) {
    case 'approved':
      return TagVariant.accent;
    case 'rejected':
      return TagVariant.neutral;
    default:
      return TagVariant.outline;
  }
}

void _viewAttachment(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          child: Image(image: resolveImageProvider(url)!),
        ),
      ),
    ),
  );
}

class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key});

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen> {
  bool _loading = true;
  String? _error;
  List<LeaveRequest> _leaves = [];
  LeaveBalance? _balance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = context.read<FieldDataState>();
      final leaves = await data.api.listMyLeaveRequests(data.spgId);
      // Best-effort — a failed balance fetch shouldn't block the rest of the list from showing.
      LeaveBalance? balance;
      try {
        balance = await data.api.getLeaveBalance(data.spgId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _leaves = leaves;
        _balance = balance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _CutiFormScreen()),
    );
    if (submitted == true) _load();
  }

  String _formatDate(String iso) {
    final d = DateTime.parse(iso);
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuti Saya', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Ajukan Cuti', onPressed: _openForm),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (_balance != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: _LeaveBalanceCard(balance: _balance!),
                      ),
                    Expanded(
                      child: _leaves.isEmpty
                          ? const EmptyState(label: 'Belum ada pengajuan cuti. Tekan + untuk mengajukan.')
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                                itemCount: _leaves.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                          final leave = _leaves[i];
                          return NocturneCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_typeLabels[leave.type] ?? leave.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    NocturneTag(_statusLabels[leave.status] ?? leave.status, variant: _statusVariant(leave.status)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 11, color: NocturneColors.textMuted(0.5)),
                                    const SizedBox(width: 4),
                                    Text(
                                      leave.startDate == leave.endDate
                                          ? _formatDate(leave.startDate)
                                          : '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
                                      style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6)),
                                    ),
                                  ],
                                ),
                                if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(leave.reason!, style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.75))),
                                ],
                                if (leave.attachmentUrl != null) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _viewAttachment(context, leave.attachmentUrl!),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: NocturneColors.divider),
                                        image: DecorationImage(
                                          image: resolveImageProvider(leave.attachmentUrl!)!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (leave.reviewedBy != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Ditinjau oleh ${leave.reviewedBy}', style: TextStyle(fontSize: 10.5, color: NocturneColors.textMuted(0.45))),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.balance});
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    return NocturneCard(
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, size: 20, color: NocturneColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sisa Cuti Tahunan ${balance.year}', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6))),
                const SizedBox(height: 2),
                Text(
                  '${balance.remaining} dari ${balance.quota} hari',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CutiFormScreen extends StatefulWidget {
  const _CutiFormScreen();

  @override
  State<_CutiFormScreen> createState() => _CutiFormScreenState();
}

class _CutiFormScreenState extends State<_CutiFormScreen> {
  String _type = 'tahunan';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  String? _attachmentUrl;
  bool _uploadingAttachment = false;
  bool _submitting = false;
  String? _error;
  LeaveBalance? _balance;
  bool _balanceLoading = false;

  @override
  void initState() {
    super.initState();
    if (_type == 'tahunan') _loadBalance();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() => _balanceLoading = true);
    try {
      final data = context.read<FieldDataState>();
      final balance = await data.api.getLeaveBalance(data.spgId);
      if (mounted) setState(() => _balance = balance);
    } catch (_) {
      // Best-effort — the backend still enforces the quota on submit either way.
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  Future<void> _pickAttachment() async {
    final api = context.read<FieldDataState>().api;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: NocturneColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NocturneRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 75);
      if (file == null) return;
      setState(() => _uploadingAttachment = true);
      final url = await api.uploadFile(File(file.path));
      if (mounted) setState(() => _attachmentUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil file: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = context.read<FieldDataState>();
      await data.api.requestLeave(
        type: _type,
        startDate: _fmt(_startDate!),
        endDate: _fmt(_endDate!),
        reason: _reasonController.text.trim(),
        attachmentUrl: _attachmentLabels.containsKey(_type) ? _attachmentUrl : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _startDate != null && _endDate != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Cuti', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          const Text('Jenis', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          NocturneCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _typeLabels.entries.map((entry) {
                return RadioListTile<String>(
                  value: entry.key,
                  groupValue: _type,
                  onChanged: (v) => setState(() {
                    _type = v!;
                    if (!_attachmentLabels.containsKey(_type)) _attachmentUrl = null;
                    if (_type == 'tahunan' && _balance == null && !_balanceLoading) _loadBalance();
                  }),
                  title: Text(entry.value, style: const TextStyle(fontSize: 13.5)),
                  dense: true,
                );
              }).toList(),
            ),
          ),
          if (_type == 'tahunan') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_available_outlined, size: 13, color: NocturneColors.textMuted(0.55)),
                const SizedBox(width: 5),
                Text(
                  _balanceLoading
                      ? 'Memuat sisa cuti…'
                      : _balance != null
                          ? 'Sisa cuti tahunan ${_balance!.year}: ${_balance!.remaining} dari ${_balance!.quota} hari'
                          : 'Sisa cuti tahunan tidak diketahui',
                  style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('Tanggal', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isStart: true),
                  child: Text(_startDate == null ? 'Mulai' : _fmt(_startDate!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isStart: false),
                  child: Text(_endDate == null ? 'Selesai' : _fmt(_endDate!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Alasan (opsional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Jelaskan alasan cuti…'),
          ),
          if (_attachmentLabels.containsKey(_type)) ...[
            const SizedBox(height: 16),
            Text(_attachmentLabels[_type]!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _uploadingAttachment ? null : _pickAttachment,
              child: Container(
                width: double.infinity,
                height: _attachmentUrl == null ? 90 : 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NocturneRadius.md),
                  border: Border.all(color: NocturneColors.divider),
                  image: _attachmentUrl == null
                      ? null
                      : DecorationImage(image: NetworkImage(_attachmentUrl!), fit: BoxFit.cover),
                ),
                child: _uploadingAttachment
                    ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : _attachmentUrl == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file_outlined, color: NocturneColors.textMuted(0.5)),
                              const SizedBox(height: 4),
                              Text('Ambil foto atau pilih dari galeri', style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5))),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: GestureDetector(
                                onTap: () => setState(() => _attachmentUrl = null),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(color: NocturneColors.bg, shape: BoxShape.circle, border: Border.all(color: NocturneColors.divider)),
                                  child: Icon(Icons.close, size: 15, color: NocturneColors.textMuted(0.7)),
                                ),
                              ),
                            ),
                          ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: valid && !_submitting ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ajukan'),
            ),
          ),
        ],
      ),
    );
  }
}
