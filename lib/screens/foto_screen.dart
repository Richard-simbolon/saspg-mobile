import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../services/wifi_service.dart';
import '../theme/nocturne_theme.dart';
import '../utils/image_provider.dart';
import '../widgets/location_error_card.dart';

const _maxTotalPhotos = 24; // 4 slot berlabel + hingga 20 foto aktivitas bebas
const _maxActivityPhotos = 20;

class FotoScreen extends StatefulWidget {
  const FotoScreen({super.key, required this.location, this.existingApprovalId});
  final OutletLocation location;
  final int? existingApprovalId;

  @override
  State<FotoScreen> createState() => _FotoScreenState();
}

class _FotoScreenState extends State<FotoScreen> {
  final Map<String, String> _photos = {}; // slot key -> uploaded file URL (before/after/rak/banner)
  final List<String> _activityPhotos = []; // open list, ditambah berulang, maks 20
  List<String> _existing = []; // foto yang sudah tersimpan dari sesi sebelumnya
  bool _loadingExisting = true;
  bool _uploading = false;
  bool _submitting = false;
  Object? _error;

  static const _slots = [
    ('before', 'Display Sebelum'),
    ('after', 'Display Sesudah'),
    ('rak', 'Kondisi Rak / Etalase'),
    ('banner', 'Banner Promosi'),
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.existingApprovalId == null) {
      setState(() => _loadingExisting = false);
      return;
    }
    try {
      final approval = await context.read<FieldDataState>().api.getApproval(widget.existingApprovalId!);
      if (mounted) setState(() => _existing = approval.photoUrls ?? []);
    } catch (_) {
      // non-fatal — admin can still add new photos even if the existing list failed to load
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  int get _queuedCount => _photos.length + _activityPhotos.length;
  int get _totalCount => _existing.length + _queuedCount;
  bool get _canAddMoreActivity => _activityPhotos.length < _maxActivityPhotos && _totalCount < _maxTotalPhotos;
  bool get _canAddSlot => _totalCount < _maxTotalPhotos;

  Future<String?> _capturePhoto() async {
    final api = context.read<FieldDataState>().api;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 640, imageQuality: 72);
      if (file == null) return null;
      setState(() => _uploading = true);
      return await api.uploadFile(File(file.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _captureSlot(String key) async {
    if (!_canAddSlot || _uploading) return;
    final uri = await _capturePhoto();
    if (uri != null) setState(() => _photos[key] = uri);
  }

  Future<void> _captureActivity() async {
    if (!_canAddMoreActivity || _uploading) return;
    final uri = await _capturePhoto();
    if (uri != null) setState(() => _activityPhotos.add(uri));
  }

  Future<void> _submit() async {
    if (_queuedCount == 0) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();
    final newPhotos = [..._photos.values, ..._activityPhotos];
    try {
      // Proves the SPG is actually at THIS outlet right now — required for later
      // stops in a multi-store day, which don't get their own check-in.
      final position = await LocationService.getPosition();
      final wifiSsid = await WifiService.currentSsid();

      var approvalId = widget.existingApprovalId;
      approvalId ??= (await data.api.createApproval(
        spgId: auth.user!.spgId!,
        brandId: widget.location.brandId,
        outlet: widget.location.name,
        note: 'Foto bukti kunjungan.',
        lat: position.latitude,
        lng: position.longitude,
        wifiSsid: wifiSsid,
      ))
          .id;
      await data.api.addApprovalPhotos(approvalId, newPhotos, lat: position.latitude, lng: position.longitude, wifiSsid: wifiSsid);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto Bukti', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          if (_existing.isNotEmpty) ...[
            Text('Foto Tersimpan (${_existing.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _ThumbGrid(uris: _existing),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: _PhotoSlot(
                  label: _slots[0].$2,
                  uri: _photos[_slots[0].$1],
                  onTap: _canAddSlot && !_uploading ? () => _captureSlot(_slots[0].$1) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhotoSlot(
                  label: _slots[1].$2,
                  uri: _photos[_slots[1].$1],
                  onTap: _canAddSlot && !_uploading ? () => _captureSlot(_slots[1].$1) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PhotoSlot(
            label: _slots[2].$2,
            uri: _photos[_slots[2].$1],
            onTap: _canAddSlot && !_uploading ? () => _captureSlot(_slots[2].$1) : null,
            height: 120,
          ),
          const SizedBox(height: 14),
          _PhotoSlot(
            label: _slots[3].$2,
            uri: _photos[_slots[3].$1],
            onTap: _canAddSlot && !_uploading ? () => _captureSlot(_slots[3].$1) : null,
            height: 100,
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Foto Aktivitas Lainnya', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
              Text(
                '${_activityPhotos.length}/$_maxActivityPhotos',
                style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dokumentasikan aktivitas lain di lokasi — bisa ditambah sekaligus atau bertahap di kunjungan berikutnya.',
            style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._activityPhotos.asMap().entries.map(
                    (e) => _RemovableThumb(uri: e.value, onRemove: () => setState(() => _activityPhotos.removeAt(e.key))),
                  ),
              if (_canAddMoreActivity)
                GestureDetector(
                  onTap: _uploading ? null : _captureActivity,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NocturneColors.divider),
                      color: NocturneColors.surface,
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: NocturneColors.textMuted(0.4), size: 20),
                  ),
                ),
            ],
          ),
          if (_totalCount >= _maxTotalPhotos) ...[
            const SizedBox(height: 8),
            Text(
              'Batas maksimal $_maxTotalPhotos foto per kunjungan sudah tercapai.',
              style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            _error is LocationFailure
                ? LocationErrorCard(failure: _error as LocationFailure, onRetry: _submit)
                : Text(_error.toString(), style: TextStyle(color: NocturneColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (_queuedCount == 0 || _submitting || _loadingExisting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_existing.isEmpty ? 'Simpan Foto' : 'Tambah Foto ($_queuedCount)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.label, required this.uri, required this.onTap, this.height = 100});
  final String label;
  final String? uri;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null && uri == null ? 0.4 : 1,
            child: Container(
              width: double.infinity,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NocturneColors.divider),
                color: NocturneColors.surface,
                image: uri == null ? null : DecorationImage(image: NetworkImage(uri!), fit: BoxFit.cover),
              ),
              child: uri == null
                  ? Center(
                      child: Icon(Icons.add_a_photo_outlined, color: NocturneColors.textMuted(0.4), size: 22),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThumbGrid extends StatelessWidget {
  const _ThumbGrid({required this.uris});
  final List<String> uris;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: uris
          .map(
            (uri) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NocturneColors.divider),
                image: DecorationImage(image: resolveImageProvider(uri)!, fit: BoxFit.cover),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RemovableThumb extends StatelessWidget {
  const _RemovableThumb({required this.uri, required this.onRemove});
  final String uri;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NocturneColors.divider),
            image: DecorationImage(image: NetworkImage(uri), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: NocturneColors.bg, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: NocturneColors.danger))),
              child: Icon(Icons.close, size: 13, color: NocturneColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}
