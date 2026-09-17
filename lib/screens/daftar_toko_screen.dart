import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/location_error_card.dart';
import '../widgets/nocturne_card.dart';
import 'location_registration_detail_screen.dart';

const _pageSize = 20;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

/// List of stores this SPG has proposed, with their review status — and the entry point to
/// propose a new one. Approval turns a pending row into a real assigned location with a weekly
/// visit schedule (see backend `LocationRegistrationRequest`); nothing else on this screen needs
/// to know that happened, the store just shows up in Jadwal/Beranda once it does.
class DaftarTokoScreen extends StatefulWidget {
  const DaftarTokoScreen({super.key});

  @override
  State<DaftarTokoScreen> createState() => _DaftarTokoScreenState();
}

class _DaftarTokoScreenState extends State<DaftarTokoScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _dateRange;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<LocationRegistrationRequest> _requests = [];
  int _total = 0;
  int _page = 1;

  bool get _hasMore => _requests.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadFirstPage);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadFirstPage();
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = context.read<FieldDataState>();
      final result = await data.api.searchMyLocationRegistrations(
        search: _searchController.text.trim(),
        from: _dateRange != null ? _isoDate(_dateRange!.start) : null,
        to: _dateRange != null ? _isoDate(_dateRange!.end) : null,
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _requests = result.items;
        _total = result.total;
        _page = 1;
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

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final data = context.read<FieldDataState>();
      final nextPage = _page + 1;
      final result = await data.api.searchMyLocationRegistrations(
        search: _searchController.text.trim(),
        from: _dateRange != null ? _isoDate(_dateRange!.start) : null,
        to: _dateRange != null ? _isoDate(_dateRange!.end) : null,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _requests = [..._requests, ...result.items];
        _total = result.total;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat lebih banyak: $e')));
    }
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _DaftarTokoFormScreen()),
    );
    if (submitted == true) _loadFirstPage();
  }

  Future<void> _openDetail(LocationRegistrationRequest req) async {
    final updated = await Navigator.of(context).push<LocationRegistrationRequest>(
      MaterialPageRoute(builder: (_) => LocationRegistrationDetailScreen(request: req)),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final i = _requests.indexWhere((r) => r.id == updated.id);
      if (i != -1) _requests[i] = updated;
    });
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Toko Saya', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Daftarkan Toko Baru', onPressed: _openForm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama toko…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined, size: 15),
                        label: Text(
                          _dateRange == null
                              ? 'Filter Tanggal'
                              : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Hapus filter tanggal',
                        onPressed: _clearDateRange,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _loadFirstPage)
                    : _requests.isEmpty
                        ? const EmptyState(label: 'Belum ada toko yang didaftarkan. Tekan + untuk mendaftarkan toko baru.')
                        : RefreshIndicator(
                            onRefresh: _loadFirstPage,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                              itemCount: _requests.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                if (i >= _requests.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                final req = _requests[i];
                                return InkWell(
                                  onTap: () => _openDetail(req),
                                  borderRadius: BorderRadius.circular(NocturneRadius.md),
                                  child: NocturneCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(req.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                            ),
                                            NocturneTag(_statusLabels[req.status] ?? req.status, variant: _statusVariant(req.status)),
                                          ],
                                        ),
                                        if (req.address != null && req.address!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(req.address!, style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.6))),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 11, color: NocturneColors.textMuted(0.5)),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDate(req.createdAt),
                                              style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6)),
                                            ),
                                          ],
                                        ),
                                        if (req.status == 'rejected' && req.reviewNote != null && req.reviewNote!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Alasan: ${req.reviewNote}',
                                            style: TextStyle(fontSize: 12, color: NocturneColors.danger),
                                          ),
                                        ],
                                      ],
                                    ),
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

class _DaftarTokoFormScreen extends StatefulWidget {
  const _DaftarTokoFormScreen();

  @override
  State<_DaftarTokoFormScreen> createState() => _DaftarTokoFormScreenState();
}

class _DaftarTokoFormScreenState extends State<_DaftarTokoFormScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _categoryController = TextEditingController();
  int? _brandId;

  Position? _position;
  LocationFailure? _locError;
  bool _locating = false;

  String? _photoUrl;
  bool _uploadingPhoto = false;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final eligibleBrands = context.read<FieldDataState>().myBrands.where((b) => b.isTokoMandiri).toList();
    if (eligibleBrands.length == 1) _brandId = eligibleBrands.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final pos = await LocationService.getPosition();
      if (mounted) setState(() => _position = pos);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locError = e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhoto() async {
    final api = context.read<FieldDataState>().api;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 75);
      if (file == null) return;
      setState(() => _uploadingPhoto = true);
      final url = await api.uploadFile(File(file.path));
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _brandId != null && _position != null && !_submitting;

  Future<void> _submit() async {
    final position = _position;
    final brandId = _brandId;
    if (position == null || brandId == null || _nameController.text.trim().isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = context.read<FieldDataState>();
      await data.api.createLocationRegistration(
        brandId: brandId,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        category: _categoryController.text.trim(),
        lat: position.latitude,
        lng: position.longitude,
        photoUrl: _photoUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibleBrands = context.watch<FieldDataState>().myBrands.where((b) => b.isTokoMandiri).toList();
    if (eligibleBrands.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daftarkan Toko Baru', style: TextStyle(fontSize: 16))),
        body: const EmptyState(label: 'Brand Anda belum mengizinkan pendaftaran toko mandiri. Hubungi admin untuk mengaktifkannya.'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Daftarkan Toko Baru', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          if (eligibleBrands.length > 1) ...[
            const Text('Brand', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _brandId,
              items: eligibleBrands
                  .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13.5))))
                  .toList(),
              onChanged: (v) => setState(() => _brandId = v),
              decoration: const InputDecoration(hintText: 'Pilih brand'),
            ),
            const SizedBox(height: 14),
          ],
          const Text('Nama Toko', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'mis. Toko Melati Jaya'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          const Text('Alamat (opsional)', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 6),
          TextField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'mis. Jl. Kartini No.45'),
          ),
          const SizedBox(height: 14),
          const Text('Kategori (opsional)', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 6),
          TextField(
            controller: _categoryController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'mis. Minimarket, Warung'),
          ),
          const SizedBox(height: 16),
          if (_locating)
            const NocturneCard(
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Mencari lokasi GPS…', style: TextStyle(fontSize: 13)),
                ],
              ),
            )
          else if (_locError != null)
            LocationErrorCard(failure: _locError!, onRetry: _captureGps)
          else if (_position != null)
            NocturneCard(
              borderColor: NocturneColors.accent800,
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: NocturneColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Titik GPS: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                      ' (akurasi ±${_position!.accuracy.round()}m)',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  TextButton(onPressed: _captureGps, child: const Text('Ulangi')),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _captureGps,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Ambil Titik GPS'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Berdiri di depan toko saat mengambil titik GPS — ini akan jadi titik absen untuk toko ini setelah disetujui admin.',
            style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
          ),
          const SizedBox(height: 16),
          const Text('Foto Etalase (opsional)', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NocturneRadius.md),
                border: Border.all(color: NocturneColors.divider),
                image: _photoUrl == null ? null : DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover),
              ),
              child: _uploadingPhoto
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : _photoUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: NocturneColors.textMuted(0.5)),
                            const SizedBox(height: 4),
                            Text('Ambil foto', style: TextStyle(fontSize: 10, color: NocturneColors.textMuted(0.5))),
                          ],
                        )
                      : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: NocturneColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Daftarkan Toko'),
            ),
          ),
        ],
      ),
    );
  }
}
