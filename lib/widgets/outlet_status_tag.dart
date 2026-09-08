import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import 'nocturne_card.dart';

class OutletStatusTag extends StatelessWidget {
  const OutletStatusTag({super.key, required this.data, required this.location});
  final FieldDataState data;
  final OutletLocation location;

  @override
  Widget build(BuildContext context) {
    // Mulai/Akhiri Kunjungan is the real per-outlet completion signal now —
    // attendance check-in/out is day-level, not per store, so it can't tell
    // this outlet's visit apart from any other one the SPG stopped at today.
    final session = data.visitSessionFor(location);
    if (session != null && !session.isOngoing) return const NocturneTag('Selesai', variant: TagVariant.accent);
    if (session != null) return const NocturneTag('Berlangsung', variant: TagVariant.outline);
    return const NocturneTag('Belum', variant: TagVariant.neutral);
  }
}
