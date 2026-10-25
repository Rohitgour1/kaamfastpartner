import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() => _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final List<dynamic> _transactions = [];
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
      final res = await context.read<PartnerApi>().walletTransactions(page: _page);
      final data = res['data'] as List?;
      if (data == null || data.isEmpty) {
        _hasMore = false;
      } else {
        _transactions.addAll(data);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Wallet Transactions')),
        backgroundColor: Colors.white,
        foregroundColor: PartnerColors.ink,
        elevation: 0.5,
      ),
      body: _busy && _transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(child: Text(context.tr('No transactions yet')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _transactions.length) {
                      _fetch();
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final t = _transactions[index];
                    final isCredit = t['type'] == 'credit' || t['type'] == 'bonus' || t['type'] == 'refund';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(
                            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isCredit ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(context.tr(t['description']?.toString() ?? 'Transaction'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          t['created_at'] != null ? DateFormat('dd MMM, yy hh:mm a').format(DateTime.parse(t['created_at'])) : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          '${isCredit ? '+' : '-'} ₹${t['amount']}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isCredit ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
