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
import '../widgets/location_error_card.dart';

const _maxPhotos = 20;

class CompetitorActivityScreen extends StatefulWidget {
  const CompetitorActivityScreen({super.key, required this.location});
  final OutletLocation location;

  @override
  State<CompetitorActivityScreen> createState() => _CompetitorActivityScreenState();
}

class _CompetitorActivityScreenState extends State<CompetitorActivityScreen> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final List<String> _photos = [];

  bool _uploading = false;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  bool get _canAddMore => _photos.length < _maxPhotos;
  bool get _canSubmit => _titleCtrl.text.trim().isNotEmpty && _descriptionCtrl.text.trim().isNotEmpty;

  Future<void> _capturePhoto() async {
    if (!_canAddMore || _uploading) return;
    final api = context.read<FieldDataState>().api;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 640, imageQuality: 72);
      if (file == null) return;
      setState(() => _uploading = true);
      final url = await api.uploadFile(File(file.path));
      if (mounted) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    if (title.isEmpty || description.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();
    try {
      // Proves the SPG is actually at THIS outlet right now — required for later
      // stops in a multi-store day, which don't get their own check-in.
      final position = await LocationService.getPosition();
      final wifiSsid = await WifiService.currentSsid();

      await data.api.createCompetitorActivity(
        spgId: auth.user!.spgId!,
        brandId: widget.location.brandId,
        outlet: widget.location.name,
        title: title,
        description: description,
        photoUrls: _photos,
        lat: position.latitude,
        lng: position.longitude,
        wifiSsid: wifiSsid,
      );
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
      appBar: AppBar(title: const Text('Aktivitas Kompetitor', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          const Text('Judul', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'mis. Promo diskon kompetitor', isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('Deskripsi', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionCtrl,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Jelaskan aktivitas kompetitor yang ditemukan di lokasi ini...',
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Foto', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
              Text(
                '${_photos.length}/$_maxPhotos',
                style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dokumentasikan aktivitas kompetitor — bisa ditambah hingga $_maxPhotos foto.',
            style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._photos.asMap().entries.map(
                    (e) => _RemovableThumb(uri: e.value, onRemove: () => setState(() => _photos.removeAt(e.key))),
                  ),
              if (_canAddMore)
                GestureDetector(
                  onTap: _uploading ? null : _capturePhoto,
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
          if (_photos.length >= _maxPhotos) ...[
            const SizedBox(height: 8),
            Text(
              'Batas maksimal $_maxPhotos foto sudah tercapai.',
              style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _error is LocationFailure
                ? LocationErrorCard(failure: _error as LocationFailure, onRetry: _submit)
                : Text(_error.toString(), style: TextStyle(color: NocturneColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (!_canSubmit || _submitting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan Aktivitas Kompetitor'),
            ),
          ),
        ],
      ),
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
              decoration: BoxDecoration(
                color: NocturneColors.bg,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: NocturneColors.danger)),
              ),
              child: Icon(Icons.close, size: 13, color: NocturneColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}
