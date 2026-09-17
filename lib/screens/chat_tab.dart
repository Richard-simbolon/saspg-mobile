import 'package:flutter/material.dart';
import '../theme/nocturne_theme.dart';

enum _Who { me, sv, sys }

class _Msg {
  _Msg(this.who, this.text, this.time, {this.name = ''});
  final _Who who;
  final String text;
  final String time;
  final String name;
}

/// Local-only placeholder — mirrors the design's chat screen 1:1, but there
/// is no realtime chat backend yet, so messages are not actually delivered
/// to a supervisor. Wiring this to a real backend (websockets or polling)
/// is a natural next step once the rest of the field app is validated.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [
    _Msg(_Who.sv, 'Selamat pagi, jangan lupa cek stok yang menipis ya.', '07:42', name: 'Supervisor'),
    _Msg(_Who.me, 'Siap Bu, segera meluncur ke lokasi.', '07:45'),
    _Msg(_Who.sv, 'Oke, foto etalase sebelum & sesudah display juga ya.', '07:46', name: 'Supervisor'),
    _Msg(_Who.sys, 'Pengingat: absen pulang sebelum pukul 17:00', '16:30'),
  ];

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _messages.add(_Msg(_Who.me, text, time));
      _ctrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            itemCount: _messages.length,
            itemBuilder: (context, i) => _Bubble(_messages[i]),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: NocturneColors.divider))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _send(),
                  style: TextStyle(color: NocturneColors.text),
                  decoration: const InputDecoration(hintText: 'Tulis pesan...', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _send,
                borderRadius: BorderRadius.circular(NocturneRadius.md),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(border: Border.all(color: NocturneColors.accent), borderRadius: BorderRadius.circular(NocturneRadius.md)),
                  child: Icon(Icons.send_outlined, size: 16, color: NocturneColors.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    if (msg.who == _Who.sys) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: NocturneColors.neutral900, borderRadius: BorderRadius.circular(8)),
          child: Text(msg.text, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5))),
        ),
      );
    }
    final isMe = msg.who == _Who.me;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && msg.name.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 2),
                child: Text(msg.name, style: TextStyle(fontSize: 10.5, color: NocturneColors.accent)),
              ),
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.transparent : NocturneColors.surface,
                border: isMe ? Border.all(color: NocturneColors.accent) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 12),
                ),
              ),
              child: Text(msg.text, style: TextStyle(fontSize: 13, color: NocturneColors.text)),
            ),
            Text(msg.time, style: TextStyle(fontSize: 10, color: NocturneColors.textMuted(0.45))),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
