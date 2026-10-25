import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/features/kyc/registration_form_card.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class KycDocumentsScreen extends StatefulWidget {
  const KycDocumentsScreen({super.key});

  @override
  State<KycDocumentsScreen> createState() => _KycDocumentsScreenState();
}

class _KycDocumentsScreenState extends State<KycDocumentsScreen> {
  Map<String, dynamic>? _status;
  List<RegistrationField> _formFields = [];
  bool _loading = true;
  String? _uploadingKey;
  String? _error;
  Timer? _poll;

  String _docKey(Map<String, dynamic> required) {
    final id = required['id'];
    if (id != null) return 'id:$id';
    return required['document_type']?.toString() ?? 'other';
  }

  bool _redirectingHome = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _syncPoll() {
    _poll?.cancel();
    if (!mounted) return;
    if (_awaitingReview || _hasPendingUploads) {
      _poll = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted) _load(quiet: true);
      });
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = context.read<PartnerApi>();
      final session = context.read<SessionController>();
      final wasGated = !session.isKycApproved;
      final data = Map<String, dynamic>.from(await api.onboardingStatus());
      final role = data['partner_type']?.toString() ??
          session.user?.role.id ??
          session.role?.id;
      data['partner_type'] ??= role;
      final moduleKeys = _selectedModuleKeys(data, session);
      final required = data['required_documents'];
      if (required is! List || required.isEmpty) {
        data['required_documents'] = await _catalogDocuments(api, role, moduleKeys);
      }
      final fields = await _loadFormFields(api, role, moduleKeys);
      if (!mounted) return;
      setState(() {
        _status = data;
        _formFields = fields;
        _loading = false;
        _error = null;
      });
      await session.refreshKyc();
      _syncPoll();
      if (wasGated && session.isKycApproved && !_redirectingHome && mounted) {
        _redirectingHome = true;
        _poll?.cancel();
        await session.unlockAfterKycApproval();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Account approved. Welcome to Home!'))),
        );
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Modules the partner actually signed up for: server approvals first, then the
  /// work types picked during onboarding. Empty only when nothing is known yet.
  Set<String> _selectedModuleKeys(Map<String, dynamic> status, SessionController session) {
    final keys = <String>{};
    final selected = status['selected_module_ids'];
    if (selected is List) {
      for (final id in selected) {
        keys.add('$id');
      }
    }
    final approvals = status['service_approvals'];
    if (approvals is List) {
      for (final row in approvals) {
        if (row is Map && row['service_module_id'] != null) {
          keys.add('${row['service_module_id']}');
        }
      }
    }
    if (keys.isEmpty) {
      for (final type in session.selectedWorkTypes) {
        final key = type.moduleId?.toString() ?? type.moduleSlug;
        if (key.isNotEmpty) keys.add(key);
      }
    }
    return keys;
  }

  /// A form built for another partner type (e.g. the laundry business form) must never show.
  static bool _formMatchesType(Object? form, String? partnerType) {
    if (form is! Map || partnerType == null) return true;
    final formType = form['partner_type']?.toString();
    return formType == null || formType.isEmpty || formType == partnerType;
  }

  Future<List<Map<String, dynamic>>> _catalogDocuments(
    PartnerApi api,
    String? partnerType,
    Set<String> moduleKeys,
  ) async {
    final byType = <String, Map<String, dynamic>>{};

    Future<void> collect(
      Iterable<String> moduleKeys, {
      required bool matchFormType,
    }) async {
      for (final key in moduleKeys) {
        try {
          final form = await api.onboardingForm(key, partnerType: partnerType);
          final formMeta = form['form'];
          if (matchFormType &&
              (formMeta is! Map || !_formMatchesType(formMeta, partnerType))) {
            continue;
          }
          final docs = form['documents'];
          if (docs is! List) continue;
          for (final item in docs) {
            if (item is! Map) continue;
            final doc = Map<String, dynamic>.from(item);
            final type = doc['document_type']?.toString() ?? 'id:${doc['id']}';
            byType.putIfAbsent(type, () => doc);
          }
        } catch (_) {}
      }
    }

    await collect(moduleKeys, matchFormType: false);
    if (byType.isEmpty && moduleKeys.isEmpty) {
      try {
        final modules = await api.onboardingServices();
        final roleKeys = <String>{};
        for (final module in modules) {
          final types = module['provider_types'];
          final list =
              types is List ? types.map((e) => '$e').toList() : const <String>[];
          if (partnerType != null && list.contains(partnerType)) {
            roleKeys.add('${module['slug'] ?? module['id']}');
          }
        }
        await collect(roleKeys, matchFormType: true);
      } catch (_) {}
    }
    return byType.values.toList();
  }

  Future<List<RegistrationField>> _loadFormFields(
    PartnerApi api,
    String? partnerType,
    Set<String> moduleKeys,
  ) async {
    final keys = {...moduleKeys};
    if (keys.isEmpty) {
      try {
        final modules = await api.onboardingServices();
        for (final module in modules) {
          final types = module['provider_types'];
          final list = types is List ? types.map((e) => '$e').toList() : const <String>[];
          if (partnerType != null && list.isNotEmpty && !list.contains(partnerType)) {
            continue;
          }
          keys.add('${module['id'] ?? module['slug']}');
        }
      } catch (_) {}
    }

    final seenModules = <int>{};
    final seenLabels = <String>{};
    final byName = <String, RegistrationField>{};
    for (final key in keys) {
      try {
        final payload = await api.onboardingForm(key, partnerType: partnerType);
        final form = payload['form'];
        if (!_formMatchesType(form, partnerType)) continue;
        final module = payload['module'];
        final moduleId = module is Map ? int.tryParse('${module['id']}') : null;
        if (moduleId != null && !seenModules.add(moduleId)) continue;
        for (final field in parseRegistrationFields(form)) {
          final label = field.label.trim().toLowerCase();
          if (byName.containsKey(field.name) ||
              (label.isNotEmpty && !seenLabels.add(label))) {
            continue;
          }
          byName[field.name] = RegistrationField(
            name: field.name,
            label: field.label,
            type: field.type,
            placeholder: field.placeholder,
            helpText: field.helpText,
            required: field.required,
            options: field.options,
            moduleId: field.moduleId ?? moduleId,
          );
        }
      } catch (_) {}
    }
    return byName.values.toList();
  }

  Map<String, dynamic> get _savedResponses {
    final raw = _status?['form_responses'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Set<String> get _uploadedTypes {
    return _uploadedDocs
        .map((doc) => doc['document_type']?.toString() ?? '')
        .where((type) => type.isNotEmpty)
        .toSet();
  }

  Future<void> _saveRegistration(Map<String, dynamic> responses) async {
    final moduleIds = _formFields.map((f) => f.moduleId).whereType<int>().toSet().toList();
    await context.read<PartnerApi>().saveFormResponses(
          responses: responses,
          serviceModuleIds: moduleIds,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Registration details saved'))),
    );
    await _load(quiet: true);
  }

  Future<void> _uploadRegistrationFile(RegistrationField field) async {
    await _pickAndUpload({
      'name': field.label,
      'document_type': documentTypeForField(field),
      'service_module_id': field.moduleId,
    });
  }

  List<Map<String, dynamic>> get _requiredDocs {
    final raw = _status?['required_documents'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get _uploadedDocs {
    final raw = _status?['documents'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? _uploadFor(Map<String, dynamic> required) {
    final requiredId = required['id'];
    final type = required['document_type']?.toString();
    for (final doc in _uploadedDocs) {
      if (requiredId != null &&
          '${doc['required_document_id']}' == '$requiredId') {
        return doc;
      }
    }
    if (type == null || type.isEmpty) return null;
    for (final doc in _uploadedDocs) {
      if (doc['document_type']?.toString() == type) return doc;
    }
    return null;
  }

  List<Map<String, dynamic>> get _mandatoryDocs {
    final required = _requiredDocs.where((d) => d['required'] != false).toList();
    return required.isEmpty ? _requiredDocs : required;
  }

  bool get _allMandatoryUploaded {
    final docs = _mandatoryDocs;
    if (docs.isEmpty) return _uploadedDocs.isNotEmpty;
    return docs.every((doc) => _uploadFor(doc) != null);
  }

  bool get _hasRejected {
    return _mandatoryDocs.any((doc) {
      final status = _uploadFor(doc)?['status']?.toString().toLowerCase();
      return status == 'rejected';
    });
  }

  bool get _hasPendingUploads {
    if (_requiredDocs.isEmpty) return _uploadedDocs.isEmpty;
    return _mandatoryDocs.any((doc) => _uploadFor(doc) == null);
  }

  bool get _awaitingReview {
    final kyc = (_status?['kyc_status']?.toString() ?? '').toLowerCase();
    if (kyc == 'approved') return false;
    if (_hasRejected) return false;
    if (!_allMandatoryUploaded) return false;
    return kyc == 'submitted' ||
        kyc == 'under_review' ||
        kyc == 'pending' ||
        _uploadedDocs.any((d) {
          final s = d['status']?.toString().toLowerCase();
          return s == 'submitted' || s == 'under_review' || s == 'pending';
        });
  }

  List<Map<String, dynamic>> get _extraUploads {
    final matched = <String>{};
    for (final required in _requiredDocs) {
      final upload = _uploadFor(required);
      if (upload?['id'] != null) matched.add('${upload!['id']}');
    }
    return _uploadedDocs
        .where((doc) => !matched.contains('${doc['id']}'))
        .toList();
  }

  String get _roleHint {
    final type = _status?['partner_type']?.toString() ??
        context.read<SessionController>().user?.role.id ??
        context.read<SessionController>().role?.id;
    final names = _requiredDocs
        .map((d) => d['name']?.toString() ?? d['document_type_label']?.toString())
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .map(context.tr)
        .toList();
    if (names.isNotEmpty) {
      return context.tr(
        'Upload {documents}. Admin will review and approve.',
        {'documents': names.join(', ')},
      );
    }
    return context.tr(switch (type) {
      'delivery' =>
        'Upload Aadhaar, driving licence, vehicle RC and bank proof.',
      'service' =>
        'Upload Aadhaar, bank proof, and PAN / police verification if asked.',
      'business' =>
        'Upload PAN, business proof, GST (if any) and bank proof.',
      _ =>
        'Upload the documents listed for your partner role. Admin will review and approve.',
    });
  }

  Future<void> _pickAndUpload(Map<String, dynamic> required) async {
    final label = required['name']?.toString() ??
        required['document_type_label']?.toString() ??
        'Document';
    final type = required['document_type']?.toString() ?? 'other';
    final requiredId = int.tryParse('${required['id'] ?? ''}');
    final moduleId = int.tryParse('${required['service_module_id'] ?? ''}');

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(context.tr('Take photo')),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.tr('Choose from gallery')),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (file == null || !mounted) return;

    final key = _docKey(required);
    setState(() => _uploadingKey = key);
    try {
      await context.read<PartnerApi>().uploadKycDocument(
            filePath: file.path,
            documentType: type,
            name: label,
            requiredDocumentId: requiredId,
            serviceModuleId: moduleId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('{name} uploaded', {'name': context.tr(label)}))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploadingKey = null);
    }
  }

  Color _statusColor(String? status) {
    return switch ((status ?? '').toLowerCase()) {
      'approved' => Colors.green.shade700,
      'rejected' => PartnerColors.danger,
      'submitted' || 'under_review' => Colors.orange.shade800,
      _ => PartnerColors.muted,
    };
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'aadhaar' => Icons.badge_outlined,
      'pan' => Icons.credit_card_outlined,
      'driving_licence' => Icons.directions_car_outlined,
      'vehicle_rc' => Icons.article_outlined,
      'insurance' => Icons.verified_user_outlined,
      'gst_certificate' => Icons.receipt_long_outlined,
      'business_proof' => Icons.storefront_outlined,
      'police_verification' => Icons.local_police_outlined,
      'profile_photo' => Icons.person_outline,
      'bank_proof' => Icons.account_balance_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  Future<void> _logout() async {
    await context.read<SessionController>().logout();
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final kyc =
        _status?['kyc_status']?.toString() ?? session.user?.kycStatus ?? 'pending';
    final kycApproved =
        kyc.toLowerCase() == 'approved' || session.isKycApproved;
    final canOperate = _status?['can_operate'] == true || kycApproved;
    final role = PartnerRole.values
        .where(
          (r) =>
              r.id ==
              (_status?['partner_type']?.toString() ??
                  session.user?.role.id ??
                  session.role?.id),
        )
        .firstOrNull;
    final extra = _extraUploads;
    final waiting = !kycApproved && _awaitingReview;
    final needsUpload = !kycApproved && !waiting;

    return PopScope(
      canPop: kycApproved || !session.needsKycGate,
      child: Scaffold(
        appBar: AppBar(
          title: Text(waiting ? context.tr('Waiting for review') : context.tr('KYC & Documents')),
          automaticallyImplyLeading: kycApproved,
          actions: [
            IconButton(
              tooltip: context.tr('Refresh'),
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
            TextButton(
              onPressed: _logout,
              child: Text(context.tr('Logout')),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading && _status == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: PartnerColors.danger),
                        ),
                      ),
                    if (waiting)
                      _WaitingBanner(roleTitle: role?.title)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: canOperate
                              ? PartnerColors.accentSoft
                              : (_hasRejected
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFFFF4E5)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              canOperate
                                  ? Icons.verified_outlined
                                  : (_hasRejected
                                      ? Icons.error_outline
                                      : Icons.upload_file_outlined),
                              color: canOperate
                                  ? PartnerColors.primary
                                  : (_hasRejected
                                      ? PartnerColors.danger
                                      : Colors.orange.shade800),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    canOperate
                                        ? context.tr('Documents approved')
                                        : (_hasRejected
                                            ? context.tr('Some documents were rejected')
                                            : context.tr('Upload your documents')),
                                    style: GoogleFonts.hankenGrotesk(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (role != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 2, bottom: 4),
                                      child: Text(
                                        context.tr(role.title),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: role.accent,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    canOperate
                                        ? context.tr('You can go online and receive jobs.')
                                        : (_hasRejected
                                            ? context.tr('Re-upload the rejected documents, then wait for admin review.')
                                            : _roleHint),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: PartnerColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (kycApproved) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          await session.unlockAfterKycApproval();
                          if (context.mounted) context.go('/home');
                        },
                        child: Text(context.tr('Continue to Home')),
                      ),
                    ],
                    if (_formFields.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      RegistrationFormCard(
                        key: ValueKey(_savedResponses.toString()),
                        fields: _formFields,
                        initial: _savedResponses,
                        readOnly: kycApproved,
                        uploadedTypes: _uploadedTypes,
                        onSave: _saveRegistration,
                        onUploadFile: _uploadRegistrationFile,
                      ),
                    ],
                    if (needsUpload || waiting || kycApproved) ...[
                      const SizedBox(height: 20),
                      Text(
                        waiting ? context.tr('Submitted documents') : context.tr('Needed documents'),
                        style: GoogleFonts.hankenGrotesk(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_requiredDocs.isEmpty && _formFields.isEmpty && !waiting)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            context.tr('No documents configured for your role yet. Pull to refresh, or contact support.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: PartnerColors.muted),
                          ),
                        ),
                      )
                    else
                      ..._requiredDocs.map((doc) {
                        final upload = _uploadFor(doc);
                        final status = upload?['status']?.toString();
                        final required = doc['required'] == true;
                        final uploading = _uploadingKey == _docKey(doc);
                        final busy = _uploadingKey != null;
                        final name = doc['name']?.toString() ??
                            doc['document_type_label']?.toString() ??
                            'Document';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PartnerColors.line),
                          ),
                          child: ListTile(
                            onTap: busy
                                ? null
                                : () async {
                                    final url = upload?['file_url']?.toString();
                                    if (url != null && url.isNotEmpty && (kycApproved || waiting || status == 'approved')) {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                      return;
                                    }
                                    if (waiting) return;
                                    await _pickAndUpload(doc);
                                  },
                            leading: Icon(
                              _iconFor(doc['document_type']?.toString()),
                              color: PartnerColors.primary,
                            ),
                            title: Text.rich(
                              TextSpan(
                                text: context.tr(name),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                children: [
                                  if (required)
                                    const TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        color: PartnerColors.danger,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (status != null)
                                  context.tr(status.replaceAll('_', ' ')),
                                if (upload?['rejection_reason'] != null)
                                  upload!['rejection_reason'],
                                if (status == null && !waiting)
                                  context.tr('Camera or gallery'),
                                if (status == null && waiting) context.tr('Missing'),
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: status == null
                                    ? PartnerColors.muted
                                    : _statusColor(status),
                              ),
                            ),
                            trailing: uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    status == 'approved'
                                        ? Icons.check_circle_outline
                                        : (waiting
                                            ? Icons.hourglass_top_rounded
                                            : Icons.upload_outlined),
                                    color: status == 'approved'
                                        ? Colors.green.shade700
                                        : PartnerColors.muted,
                                  ),
                          ),
                        );
                      }),
                    if (extra.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.tr('Other uploaded'),
                        style: GoogleFonts.hankenGrotesk(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...extra.map((doc) {
                        final status = doc['status']?.toString() ?? 'submitted';
                        return Card(
                          child: ListTile(
                            title: Text(
                              context.tr(
                                doc['name']?.toString() ??
                                    doc['document_type']?.toString() ??
                                    'Document',
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (doc['document_type'] != null)
                                  context.tr(doc['document_type'].toString().replaceAll('_', ' ')),
                                if (doc['rejection_reason'] != null)
                                  doc['rejection_reason'],
                              ].whereType<String>().join(' · '),
                            ),
                            trailing: Text(
                              context.tr(status.replaceAll('_', ' ')),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _statusColor(status),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({this.roleTitle});

  final String? roleTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PartnerColors.primaryDeep, PartnerColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('Waiting for review'),
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            roleTitle == null
                ? context.tr('Your documents are submitted. Home stays locked until an admin approves every document.')
                : context.tr(
                    'Your {role} documents are submitted. Home stays locked until an admin approves every document.',
                    {'role': context.tr(roleTitle!)},
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('This screen refreshes automatically'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
