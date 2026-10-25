import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _holder = TextEditingController();
  final _number = TextEditingController();
  final _ifsc = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _holder.dispose();
    _number.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context.read<PartnerApi>().bankAccount();
      final account = raw['bank_account'];
      final map = account is Map
          ? Map<String, dynamic>.from(account)
          : const <String, dynamic>{};
      if (!mounted) return;
      _holder.text = map['account_holder_name']?.toString() ?? '';
      _number.text = map['account_number']?.toString() ?? '';
      _ifsc.text = (map['ifsc_code'] ?? map['ifsc'])?.toString() ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final name = _holder.text.trim();
    final number = _number.text.replaceAll(RegExp(r'\s'), '');
    final ifsc = _ifsc.text.trim().toUpperCase();

    if (name.length < 2) {
      _toast(context.tr('Enter account holder name'));
      return;
    }
    if (!RegExp(r'^[0-9]{9,18}$').hasMatch(number)) {
      _toast(context.tr('Enter a valid 9–18 digit account number'));
      return;
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      _toast(context.tr('Enter a valid IFSC code'));
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<PartnerApi>().updateBankAccount(
        accountHolderName: name,
        accountNumber: number,
        ifscCode: ifsc,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Payment method'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.tr('Bank account for wallet withdrawals. One account is saved and updated in place.'),
                  style: const TextStyle(color: PartnerColors.muted),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: PartnerColors.danger),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Account holder name'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(18),
                  ],
                  decoration: InputDecoration(
                    labelText: context.tr('Account number'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ifsc,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saving ? null : _save(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: context.tr('IFSC code'),
                    hintText: 'SBIN0001234',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(context.tr(_saving ? 'Saving…' : 'Save payment method')),
                ),
              ],
            ),
    );
  }
}
