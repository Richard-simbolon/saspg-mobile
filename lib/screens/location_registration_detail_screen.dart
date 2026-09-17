import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/location_error_card.dart';
import '../widgets/nocturne_card.dart';

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

/// Detail view of one submitted store. While it's still `pending`, every field stays editable —
/// approval/rejection freezes the record, so past that point this is a read-only summary
/// (including the admin's note, if rejected). Saving pops back with the updated request so the
/// list screen can patch its item in place without a full reload.
class LocationRegistrationDetailScreen extends StatefulWidget {
  const LocationRegistrationDetailScreen({super.key, required this.request});
  final LocationRegistrationRequest request;

  @override
  State<LocationRegistrationDetailScreen> createState() => _LocationRegistrationDetailScreenState();
}

class _LocationRegistrationDetailScreenState extends State<LocationRegistrationDetailScreen> {
  late final _nameController = TextEditingController(text: widget.request.name);
  late final _addressController = TextEditingController(text: widget.request.address ?? '');
  late final _categoryController = TextEditingController(text: widget.request.category ?? '');

  late double _lat = widget.request.lat;
  late double _lng = widget.request.lng;
  Position? _freshPosition;
  LocationFailure? _locError;
  bool _locating = false;

  late String? _photoUrl = widget.request.photoUrl;
  bool _uploadingPhoto = false;

  bool _saving = false;
  String? _error;

  bool get _isPending => widget.request.status == 'pending';

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _recaptureGps() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final pos = await LocationService.getPosition();
      if (mounted) {
        setState(() {
          _freshPosition = pos;
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
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

  bool get _canSave => _nameController.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<FieldDataState>().api;
      final updated = await api.updateLocationRegistration(
        widget.request.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        category: _categoryController.text.trim(),
        lat: _lat,
        lng: _lng,
        photoUrl: _photoUrl,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Scaffold(
      appBar: AppBar(title: Text(_isPending ? 'Edit Toko' : 'Detail Toko', style: const TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              NocturneTag(_statusLabels[req.status] ?? req.status, variant: _statusVariant(req.status)),
              const SizedBox(width: 8),
              Text(
                'Diajukan ${_formatDate(req.createdAt)}',
                style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.55)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (req.status == 'rejected' && req.reviewNote != null && req.reviewNote!.isNotEmpty) ...[
            NocturneCard(
              borderColor: NocturneColors.danger,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: NocturneColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Alasan ditolak: ${req.reviewNote}', style: TextStyle(fontSize: 12.5, color: NocturneColors.danger)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_isPending) ...[
            _ReadOnlyField(label: 'Nama Toko', value: req.name),
            if (req.address != null && req.address!.isNotEmpty) _ReadOnlyField(label: 'Alamat', value: req.address!),
            if (req.category != null && req.category!.isNotEmpty) _ReadOnlyField(label: 'Kategori', value: req.category!),
            _ReadOnlyField(label: 'Titik GPS', value: '${req.lat.toStringAsFixed(5)}, ${req.lng.toStringAsFixed(5)}'),
            if (req.photoUrl != null) ...[
              const SizedBox(height: 4),
              const Text('Foto Etalase', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(NocturneRadius.md),
                child: Image.network(req.photoUrl!, width: 140, height: 140, fit: BoxFit.cover),
              ),
            ],
          ] else ...[
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
              LocationErrorCard(failure: _locError!, onRetry: _recaptureGps)
            else
              NocturneCard(
                borderColor: NocturneColors.accent800,
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: NocturneColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Titik GPS: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}'
                        '${_freshPosition != null ? ' (akurasi ±${_freshPosition!.accuracy.round()}m)' : ''}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    TextButton(onPressed: _recaptureGps, child: const Text('Ambil Ulang')),
                  ],
                ),
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
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
