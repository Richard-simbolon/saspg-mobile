import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = [];

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
      final list = await data.api.listNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
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

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        final data = context.read<FieldDataState>();
        final updated = await data.api.markNotificationRead(n.id);
        if (!mounted) return;
        setState(() {
          _notifications = [
            for (final item in _notifications) item.id == n.id ? updated : item,
          ];
        });
        data.refreshNotificationCount();
      } catch (_) {
        // Marking read is best-effort — the notification stays visible either way.
      }
    }
  }

  static String _formatTime(DateTime t) {
    final local = t.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi', style: TextStyle(fontSize: 16))),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _notifications.isEmpty
                  ? const EmptyState(label: 'Belum ada notifikasi.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final n = _notifications[i];
                          return NocturneCard(
                            onTap: () => _open(n),
                            borderColor: n.isRead ? null : NocturneColors.accent800,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    NocturneTag(
                                      n.isRead ? 'Sudah dibaca' : 'Belum dibaca',
                                      variant: n.isRead ? TagVariant.neutral : TagVariant.accent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.body,
                                  style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.75), height: 1.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(n.createdAt),
                                  style: TextStyle(fontSize: 10.5, color: NocturneColors.textMuted(0.45)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
