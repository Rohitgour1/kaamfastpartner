import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/core/app_constants.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:kaamfast_partner/widgets/legal_links.dart';
import 'package:kaamfast_partner/widgets/otp_boxes.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _referralController = TextEditingController();
  bool _otpStep = false;
  bool _profileStep = false;
  bool _needsProfile = true;
  bool _loading = false;
  bool _acceptedTerms = false;
  String? _hintOtp;
  String _otpCode = '';

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _email.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _sendOtp() async {
    if (_digits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter a valid 10-digit mobile number'))),
      );
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Please accept the Terms & Conditions and Privacy Policy to continue.'),
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    try {
      final res = await session.sendOtp(_digits);
      if (!mounted) return;
      _hintOtp = res['debug_otp']?.toString() ?? AppConstants.debugOtpHint;
      setState(() {
        _loading = false;
        _otpStep = true;
        _needsProfile = res['needs_profile'] != false;
        _otpCode = _hintOtp ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _afterOtp([String? code]) async {
    final otp = (code ?? _otpCode).replaceAll(RegExp(r'\D'), '');
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter the 6-digit OTP'))),
      );
      return;
    }
    _otpCode = otp;
    if (_needsProfile) {
      setState(() => _profileStep = true);
      return;
    }
    await _verify();
  }

  Future<void> _verify() async {
    final otp = _otpCode.replaceAll(RegExp(r'\D'), '');
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter the 6-digit OTP'))),
      );
      return;
    }
    if (_needsProfile) {
      if (_name.text.trim().length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Enter your full name'))),
        );
        return;
      }
      if (!_email.text.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Enter a valid email'))),
        );
        return;
      }
    }
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    try {
      await session.verifyOtp(
        otp,
        name: _needsProfile ? _name.text.trim() : null,
        email: _needsProfile ? _email.text.trim() : null,
        referralCode: _needsProfile && _referralController.text.trim().isNotEmpty ? _referralController.text.trim() : null,
      );
      if (!mounted) return;
      context.go(session.isKycApproved ? '/home' : '/kyc');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_profileStep) {
              setState(() => _profileStep = false);
            } else if (_otpStep) {
              setState(() => _otpStep = false);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_otpStep) ...[
                Text(context.tr('Welcome Back'), style: GoogleFonts.hankenGrotesk(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  context.tr('Enter your mobile number to access your workspace.'),
                  style: const TextStyle(color: PartnerColors.muted),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: context.tr('Mobile number'),
                    prefixText: '+91  ',
                  ),
                  onChanged: (v) {
                    final d = v.replaceAll(RegExp(r'\D'), '');
                    if (d.length > 10) return;
                    var formatted = d;
                    if (d.length > 5) {
                      formatted = '${d.substring(0, 5)} ${d.substring(5)}';
                    }
                    if (formatted != v) {
                      _phone.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TermsConsent(
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _loading || _digits.length != 10 ? null : _sendOtp,
                  child: Text(_loading ? context.tr('Sending…') : context.tr('Continue')),
                ),
              ] else if (!_profileStep) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PartnerColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(context.tr('Enter 6-Digit OTP'), style: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  context.tr('OTP sent to +91 {phone}', {'phone': _phone.text}),
                  style: const TextStyle(color: PartnerColors.muted),
                ),
                // if (_hintOtp != null) ...[
                //   const SizedBox(height: 8),
                //   Text('Dev OTP: $_hintOtp', style: const TextStyle(color: PartnerColors.accent, fontWeight: FontWeight.w700)),
                // ],
                const SizedBox(height: 28),
                OtpBoxes(
                  initialValue: _otpCode,
                  onChanged: (v) => _otpCode = v,
                  onCompleted: (v) {
                    if (!_loading) _afterOtp(v);
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _loading ? null : _afterOtp,
                  child: Text(
                    _loading
                        ? context.tr('Verifying…')
                        : (_needsProfile ? context.tr('Continue') : context.tr('Verify & Enter Workspace')),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Complete your profile'), style: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('Tell us your name and email so customers and payouts can reach you.'),
                          style: const TextStyle(color: PartnerColors.muted),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(labelText: context.tr('Full name')),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: context.tr('Email')),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _referralController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: context.tr('Referral code (optional)'),
                            hintText: context.tr('Enter invite code if you have one'),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _verify,
                  child: Text(_loading ? context.tr('Saving…') : context.tr('Create account')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
