import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';

TagVariant _statusVariant(String status) => status == 'paid' ? TagVariant.accent : TagVariant.outline;
String _statusLabel(String status) => status == 'paid' ? 'Dibayar' : 'Draft';

String _periodLabel(String period) {
  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  final parts = period.split('-');
  final month = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  return '${months[(month - 1).clamp(0, 11)]} ${parts[0]}';
}

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  bool _loading = true;
  String? _error;
  List<Payslip> _payslips = [];

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
      final payslips = await data.api.listMyPayslips();
      if (!mounted) return;
      setState(() {
        _payslips = payslips;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slip Gaji', style: TextStyle(fontSize: 16))),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _payslips.isEmpty
                  ? const EmptyState(label: 'Belum ada slip gaji yang diterbitkan.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        itemCount: _payslips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final slip = _payslips[i];
                          return _PayslipTile(
                            slip: slip,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => _PayslipDetailScreen(slip: slip)),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _PayslipTile extends StatelessWidget {
  const _PayslipTile({required this.slip, required this.onTap});
  final Payslip slip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: NocturneCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_periodLabel(slip.period), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                NocturneTag(_statusLabel(slip.status), variant: _statusVariant(slip.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatRp(slip.netSalary),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: NocturneColors.accent),
            ),
            const SizedBox(height: 4),
            Text('Gaji bersih', style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55))),
          ],
        ),
      ),
    );
  }
}

class _PayslipDetailScreen extends StatelessWidget {
  const _PayslipDetailScreen({required this.slip});
  final Payslip slip;

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: NocturneColors.textMuted(0.65))),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_periodLabel(slip.period), style: const TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kehadiran', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: NocturneColors.textMuted(0.6))),
                const Divider(height: 18),
                _row('Hari Terjadwal', '${slip.scheduledDays} hari'),
                _row('Hari Hadir', '${slip.presentDays} hari'),
                _row('Cuti Disetujui', '${slip.approvedLeaveDays} hari'),
                _row(
                  'Alpha (Tanpa Keterangan)',
                  '${slip.unpaidAbsenceDays} hari',
                  valueColor: slip.unpaidAbsenceDays > 0 ? Colors.redAccent : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rincian Gaji', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: NocturneColors.textMuted(0.6))),
                const Divider(height: 18),
                _row('Gaji Pokok', formatRp(slip.basicSalary)),
                _row(
                  'Potongan Absensi',
                  slip.attendanceDeduction > 0 ? '- ${formatRp(slip.attendanceDeduction)}' : '-',
                  valueColor: slip.attendanceDeduction > 0 ? Colors.redAccent : null,
                ),
                _row(
                  'Potongan BPJS Kesehatan',
                  slip.bpjsKesehatanDeduction > 0 ? '- ${formatRp(slip.bpjsKesehatanDeduction)}' : '-',
                  valueColor: slip.bpjsKesehatanDeduction > 0 ? Colors.redAccent : null,
                ),
                _row(
                  'Potongan BPJS Ketenagakerjaan',
                  slip.bpjsKetenagakerjaanDeduction > 0 ? '- ${formatRp(slip.bpjsKetenagakerjaanDeduction)}' : '-',
                  valueColor: slip.bpjsKetenagakerjaanDeduction > 0 ? Colors.redAccent : null,
                ),
                _row(
                  'Insentif Brand',
                  slip.incentiveTotal > 0 ? '+ ${formatRp(slip.incentiveTotal)}' : '-',
                  valueColor: slip.incentiveTotal > 0 ? NocturneColors.accent : null,
                ),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gaji Bersih', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(formatRp(slip.netSalary), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: NocturneColors.accent)),
                  ],
                ),
              ],
            ),
          ),
          if (slip.paidAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Dibayar pada ${slip.paidAt!.day}/${slip.paidAt!.month}/${slip.paidAt!.year}',
              style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
