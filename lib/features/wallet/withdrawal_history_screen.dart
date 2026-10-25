import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() => _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  final List<dynamic> _withdrawals = [];
  bool _busy = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!_hasMore) return;
    try {
      final res = await context.read<PartnerApi>().withdrawalHistory(page: _page);
      final data = res['data'] as List?;
      if (data == null || data.isEmpty) {
        _hasMore = false;
      } else {
        _withdrawals.addAll(data);
        _page++;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'processed') return Colors.green;
    if (status == 'failed') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Withdrawal History')),
        backgroundColor: Colors.white,
        foregroundColor: PartnerColors.ink,
        elevation: 0.5,
      ),
      body: _busy && _withdrawals.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _withdrawals.isEmpty
              ? Center(child: Text(context.tr('No withdrawal requests found.')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _withdrawals.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _withdrawals.length) {
                      _fetch();
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final w = _withdrawals[index];
                    final statusColor = _getStatusColor(w['status']?.toString() ?? 'requested');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${w['amount']}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    context.tr(w['status']?.toString() ?? 'Requested').toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (w['upi_id'] != null) Text(context.tr('UPI: {id}', {'id': w['upi_id']}), style: const TextStyle(color: PartnerColors.muted)),
                            if (w['account_name'] != null) Text(context.tr('Account: {name}', {'name': w['account_name']}), style: const TextStyle(color: PartnerColors.muted)),
                            if (w['notes'] != null) Text(context.tr('Note: {note}', {'note': w['notes']}), style: const TextStyle(color: PartnerColors.muted, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Text(
                              w['created_at'] != null ? DateFormat('dd MMM, yy hh:mm a').format(DateTime.parse(w['created_at'])) : '',
                              style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
