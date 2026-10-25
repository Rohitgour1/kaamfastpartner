import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class PartnerNotificationsScreen extends StatefulWidget {
  const PartnerNotificationsScreen({super.key});

  @override
  State<PartnerNotificationsScreen> createState() =>
      _PartnerNotificationsScreenState();
}

class _PartnerNotificationsScreenState
    extends State<PartnerNotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<PartnerApi>().notifications();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<PartnerApi>().markAllNotificationsRead();
              await _load();
            },
            child: Text(context.tr('Read all')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(context.tr('No notifications yet'))),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final unread = item['read_at'] == null;
                  return Card(
                    color: unread ? PartnerColors.accentSoft : Colors.white,
                    child: ListTile(
                      title: Text(
                        context.tr(item['title']?.toString() ?? 'Update'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item['body']?.toString() ?? ''),
                      onTap: () async {
                        final id = item['id'];
                        final type = item['type']?.toString() ?? '';
                        if (type.startsWith('service.')) {
                          context.push('/my-services');
                        } else if (type == 'booking.available') {
                          context.go('/home');
                        }
                        if (id is int)
                          await context.read<PartnerApi>().markNotificationRead(
                            id,
                          );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
