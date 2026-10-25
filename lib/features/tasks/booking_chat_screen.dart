import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({
    super.key,
    required this.bookingId,
    this.title = 'Booking chat',
  });

  final int bookingId;
  final String title;

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final Map<int, Map<String, dynamic>> _byId = {};
  bool _loading = true;
  bool _sending = false;
  StreamSubscription<DatabaseEvent>? _sub;

  List<Map<String, dynamic>> get _messages {
    final rows = _byId.values.toList()
      ..sort((a, b) {
        final ai = (a['id'] as num?)?.toInt() ?? 0;
        final bi = (b['id'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });
    return rows;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadHistory();
    _listenFirebase();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _loading = true);
    try {
      final api = context.read<SessionController>().api;
      final data = await api.bookingChat(widget.bookingId);
      final list = data['messages'];
      if (list is List) {
        for (final item in list) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] as num?)?.toInt();
          if (id == null) continue;
          _byId[id] = map;
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
      _jumpToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _listenFirebase() {
    try {
      _sub = FirebaseDatabase.instance
          .ref('live/bookings/${widget.bookingId}/chat')
          .onValue
          .listen((event) {
        final value = event.snapshot.value;
        if (value is! Map) return;
        var changed = false;
        value.forEach((key, raw) {
          if (raw is! Map) return;
          final map = Map<String, dynamic>.from(raw);
          final id = (map['id'] as num?)?.toInt() ?? int.tryParse('$key');
          if (id == null) return;
          final prev = _byId[id];
          if (prev == null || prev['body'] != map['body']) {
            _byId[id] = map;
            changed = true;
          }
        });
        if (!changed || !mounted) return;
        setState(() {});
        _jumpToEnd();
      });
    } catch (e) {
      debugPrint('Booking chat Firebase listen skipped: $e');
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final optimisticId = -DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _byId[optimisticId] = {
        'id': optimisticId,
        'sender_type': 'partner',
        'body': body,
        'created_at': DateTime.now().toIso8601String(),
      };
    });
    _input.clear();
    _jumpToEnd();
    try {
      final api = context.read<SessionController>().api;
      final sent = await api.sendBookingChat(widget.bookingId, body);
      final realId = (sent['id'] as num?)?.toInt();
      if (realId != null && mounted) {
        setState(() {
          _byId.remove(optimisticId);
          _byId[realId] = Map<String, dynamic>.from(sent);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _byId.remove(optimisticId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F4),
      appBar: AppBar(
        title: Text(context.tr(widget.title)),
        actions: [
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.isEmpty ? 1 : messages.length,
                    itemBuilder: (context, index) {
                      if (messages.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              context.tr('No messages yet. Say hello to start.'),
                              style: const TextStyle(color: PartnerColors.muted),
                            ),
                          ),
                        );
                      }
                      final m = messages[index];
                      final mine = m['sender_type']?.toString() == 'partner';
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? PartnerColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: mine ? null : Border.all(color: PartnerColors.line),
                          ),
                          child: Text(
                            m['body']?.toString() ?? '',
                            style: TextStyle(
                              color: mine ? Colors.white : PartnerColors.ink,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.tr('Type a message…'),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: PartnerColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: PartnerColors.line),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: PartnerColors.primary),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
