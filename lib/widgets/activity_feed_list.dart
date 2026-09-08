import 'package:flutter/material.dart';
import '../services/activity_feed.dart';
import '../theme/nocturne_theme.dart';
import 'nocturne_card.dart';

/// Renders a merged Activity feed as a dot-and-line timeline — shared by the
/// Beranda preview and the full Activity history screen so both read the same.
class ActivityFeedList extends StatelessWidget {
  const ActivityFeedList({super.key, required this.events});
  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('Belum ada aktivitas tercatat.', style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.55)));
    }
    return Column(
      children: [
        for (int i = 0; i < events.length; i++)
          _ActivityRow(event: events[i], isLast: i == events.length - 1),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event, required this.isLast});
  final ActivityEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: event.color),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 1, color: NocturneColors.divider)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(event.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        activityRelativeTime(event.date),
                        style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.45)),
                      ),
                    ],
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(event.description, style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.6))),
                  ],
                  if (event.badgeLabel != null) ...[
                    const SizedBox(height: 6),
                    NocturneTag(event.badgeLabel!, variant: event.badgeVariant ?? TagVariant.neutral),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
