import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class EditPartnerProfileScreen extends StatefulWidget {
  const EditPartnerProfileScreen({super.key});

  @override
  State<EditPartnerProfileScreen> createState() => _EditPartnerProfileScreenState();
}

class _EditPartnerProfileScreenState extends State<EditPartnerProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  File? _photo;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _syncFields(session);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await session.refreshProfile();
        if (!mounted) return;
        _syncFields(session);
        setState(() {});
      } catch (_) {
        if (!mounted) return;
        _syncFields(session);
        setState(() {});
      }
    });
  }

  void _syncFields(SessionController session) {
    final user = session.user;
    if ((user?.name ?? '').isNotEmpty) {
      _name.text = user!.name;
    }
    if ((user?.email ?? '').isNotEmpty) {
      _email.text = user!.email!;
    }
    _phone.text = _formattedPhone(
      mobile: user?.mobile,
      fallback: session.phone,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('Choose from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.tr('Take a photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (picked == null || !mounted) return;
    setState(() {
      _photo = File(picked.path);
      _uploading = true;
    });
    try {
      await context.read<SessionController>().updateAvatar(picked.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Photo updated'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enter your full name'))));
      return;
    }
    if (!_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enter a valid email'))));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SessionController>().updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Profile updated'))));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final phoneLabel = _formattedPhone(
      mobile: user?.mobile,
      fallback: session.phone,
    );
    if (_phone.text != phoneLabel) {
      _phone.value = TextEditingValue(text: phoneLabel);
    }
    final avatar = _photo != null
        ? FileImage(_photo!)
        : (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Edit profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: PartnerColors.accentSoft,
                      backgroundImage: avatar as ImageProvider?,
                      child: avatar == null
                          ? Text(
                              (user?.name ?? 'P').characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: PartnerColors.primary,
                              ),
                            )
                          : null,
                    ),
                    if (_uploading) const CircularProgressIndicator(),
                  ],
                ),
                TextButton.icon(
                  onPressed: _uploading ? null : _pickPhoto,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(context.tr('Change photo')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            controller: _phone,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: InputDecoration(
              labelText: context.tr('Phone'),
              helperText: context.tr('Phone number cannot be changed. Contact support if you need help.'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(context.tr(_saving ? 'Saving…' : 'Save profile')),
          ),
        ],
      ),
    );
  }

  String _formattedPhone({String? mobile, String? fallback}) {
    final raw = (mobile ?? fallback ?? '').replaceAll(RegExp(r'\D'), '');
    const country = '+91';
    if (raw.isEmpty) return '$country —';
    final local = raw.length > 10 ? raw.substring(raw.length - 10) : raw;
    if (local.length == 10) {
      return '$country ${local.substring(0, 5)} ${local.substring(5)}';
    }
    return '$country $local';
  }
}
