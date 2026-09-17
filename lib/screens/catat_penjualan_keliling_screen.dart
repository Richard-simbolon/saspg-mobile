import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/location_error_card.dart';
import '../widgets/nocturne_card.dart';

/// Records one direct/roaming sale — multiple products per transaction, a photo (taken with
/// the customer) and the SPG's live GPS point at submission, since there's no fixed outlet to
/// check presence against (see `penjualan_screen.dart` for the outlet-based sibling flow).
class CatatPenjualanKelilingScreen extends StatefulWidget {
  const CatatPenjualanKelilingScreen({super.key, required this.brandId});
  final int brandId;

  @override
  State<CatatPenjualanKelilingScreen> createState() => _CatatPenjualanKelilingScreenState();
}

class _CatatPenjualanKelilingScreenState extends State<CatatPenjualanKelilingScreen> {
  final Map<int, int> _qty = {};
  final _catatanController = TextEditingController();

  Position? _position;
  LocationFailure? _locError;
  bool _locating = false;

  String? _photoUrl;
  bool _uploadingPhoto = false;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  num _total(List<Product> products) => products.fold<num>(0, (sum, p) => sum + (p.price * (_qty[p.id] ?? 0)));

  bool get _hasItems => _qty.values.any((q) => q > 0);

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

  bool get _canSubmit => _hasItems && _position != null && _photoUrl != null && !_submitting;

  Future<void> _submit(List<Product> products) async {
    final position = _position;
    final photoUrl = _photoUrl;
    if (position == null || photoUrl == null) return;
    final items = products
        .where((p) => (_qty[p.id] ?? 0) > 0)
        .map((p) => {'productId': p.id, 'qty': _qty[p.id]!})
        .toList();
    if (items.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await data.api.createDailySalesReport(
        spgId: auth.user!.spgId!,
        brandId: widget.brandId,
        outlet: _catatanController.text.trim().isNotEmpty ? _catatanController.text.trim() : 'Penjualan Keliling',
        date: today,
        items: items,
        lat: position.latitude,
        lng: position.longitude,
        photoUrl: photoUrl,
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
    final data = context.watch<FieldDataState>();
    final products = data.brandById(widget.brandId)?.products ?? const <Product>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Catat Penjualan', style: TextStyle(fontSize: 16))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              children: [
                const Text('Produk Terjual', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
                const SizedBox(height: 8),
                ...products.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NocturneCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text('${formatRp(p.price)} / bungkus', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.55))),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _QtyButton(
                                icon: Icons.remove,
                                onTap: () => setState(() => _qty[p.id] = ((_qty[p.id] ?? 0) - 1).clamp(0, 9999)),
                              ),
                              SizedBox(
                                width: 28,
                                child: Text('${_qty[p.id] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                              ),
                              _QtyButton(icon: Icons.add, onTap: () => setState(() => _qty[p.id] = (_qty[p.id] ?? 0) + 1)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Catatan Lokasi (opsional)', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
                const SizedBox(height: 6),
                TextField(
                  controller: _catatanController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'mis. Depan Indomaret Jl. Sudirman'),
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
                            'Titik GPS: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
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
                const SizedBox(height: 16),
                const Text('Bukti Foto (wajib)', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
                const SizedBox(height: 4),
                Text(
                  'Ambil foto bersama pelanggan sebagai bukti transaksi.',
                  style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
                ),
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
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: NocturneColors.divider))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Penjualan', style: TextStyle(fontSize: 13, color: NocturneColors.textMuted(0.6))),
                    Text(formatRp(_total(products)), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: NocturneColors.danger, fontSize: 12.5)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? () => _submit(products) : null,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kirim Data Penjualan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: NocturneColors.divider), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 13),
      ),
    );
  }
}
