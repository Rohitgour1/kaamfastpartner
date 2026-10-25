import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';

class RegistrationField {
  const RegistrationField({
    required this.name,
    required this.label,
    required this.type,
    this.placeholder,
    this.helpText,
    this.required = false,
    this.options = const [],
    this.moduleId,
  });

  final String name;
  final String label;
  final String type;
  final String? placeholder;
  final String? helpText;
  final bool required;
  final List<({String label, String value})> options;
  final int? moduleId;

  bool get isFile => type == 'image' || type == 'document';
}

class RegistrationFormCard extends StatefulWidget {
  const RegistrationFormCard({
    super.key,
    required this.fields,
    required this.initial,
    required this.readOnly,
    required this.onSave,
    required this.onUploadFile,
    this.uploadedTypes = const {},
  });

  final List<RegistrationField> fields;
  final Map<String, dynamic> initial;
  final bool readOnly;
  final Future<void> Function(Map<String, dynamic> responses) onSave;
  final Future<void> Function(RegistrationField field) onUploadFile;
  final Set<String> uploadedTypes;

  @override
  State<RegistrationFormCard> createState() => _RegistrationFormCardState();
}

class _RegistrationFormCardState extends State<RegistrationFormCard> {
  final _values = <String, dynamic>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _copyInitial();
  }

  @override
  void didUpdateWidget(RegistrationFormCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) _copyInitial();
  }

  void _copyInitial() {
    _values
      ..clear()
      ..addAll(widget.initial);
  }

  Future<void> _save() async {
    for (final field in widget.fields.where((f) => !f.isFile && f.required)) {
      final value = _values[field.name];
      final empty = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);
      if (empty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('{field} is required', {'field': context.tr(field.label)}))),
        );
        return;
      }
    }

    final answers = <String, dynamic>{};
    for (final field in widget.fields.where((f) => !f.isFile)) {
      if (_values.containsKey(field.name)) answers[field.name] = _values[field.name];
    }
    if (answers.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(answers);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textFields = widget.fields.where((f) => !f.isFile).toList();
    final fileFields = widget.fields.where((f) => f.isFile).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Registration details'),
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PartnerColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...textFields.map(_field),
              if (textFields.isNotEmpty && !widget.readOnly) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? context.tr('Saving…') : context.tr('Save details')),
                  ),
                ),
              ],
              if (fileFields.isNotEmpty) ...[
                if (textFields.isNotEmpty) const SizedBox(height: 14),
                Text(
                  context.tr('Documents from this form'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...fileFields.map(_fileTile),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(RegistrationField field) {
    final value = _values[field.name];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: context.tr(field.label),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              children: [
                if (field.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: PartnerColors.danger),
                  ),
              ],
            ),
          ),
          if (field.helpText != null && field.helpText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                context.tr(field.helpText!),
                style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
              ),
            )
          else
            const SizedBox(height: 6),
          _input(field, value),
        ],
      ),
    );
  }

  Widget _input(RegistrationField field, dynamic value) {
    switch (field.type) {
      case 'dropdown':
      case 'radio':
        final current = value?.toString() ?? '';
        final known = field.options.any((option) => option.value == current);
        return DropdownButtonFormField<String>(
          value: known ? current : null,
          items: field.options
              .map(
                (option) => DropdownMenuItem(
                  value: option.value,
                  child: Text(context.tr(option.label)),
                ),
              )
              .toList(),
          onChanged: widget.readOnly
              ? null
              : (next) => setState(() => _values[field.name] = next),
          decoration: _decoration(context.tr(field.placeholder ?? 'Select')),
        );
      case 'checkbox':
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: value == true || value == '1' || value == 'true',
          onChanged: widget.readOnly
              ? null
              : (next) => setState(() => _values[field.name] = next == true),
          title: Text(context.tr(field.placeholder ?? field.label)),
        );
      case 'multi_select':
        final selected = value is List
            ? value.map((e) => '$e').toSet()
            : value?.toString().split(',').where((e) => e.isNotEmpty).toSet() ?? <String>{};
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((option) {
            final on = selected.contains(option.value);
            return FilterChip(
              label: Text(context.tr(option.label)),
              selected: on,
              onSelected: widget.readOnly
                  ? null
                  : (next) {
                      final copy = {...selected};
                      if (next) {
                        copy.add(option.value);
                      } else {
                        copy.remove(option.value);
                      }
                      setState(() => _values[field.name] = copy.toList());
                    },
            );
          }).toList(),
        );
      case 'textarea':
      case 'address':
      case 'location':
        return TextFormField(
          initialValue: value?.toString() ?? '',
          readOnly: widget.readOnly,
          minLines: 2,
          maxLines: 4,
          decoration: _decoration(context.tr(field.placeholder ?? field.label)),
          onChanged: (text) => _values[field.name] = text,
        );
      default:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          readOnly: widget.readOnly,
          keyboardType: switch (field.type) {
            'number' => TextInputType.number,
            'phone' => TextInputType.phone,
            'email' => TextInputType.emailAddress,
            _ => TextInputType.text,
          },
          decoration: _decoration(context.tr(field.placeholder ?? field.label)),
          onChanged: (text) => _values[field.name] = text,
        );
    }
  }

  Widget _fileTile(RegistrationField field) {
    final type = documentTypeForField(field);
    final uploaded = widget.uploadedTypes.contains(type) ||
        widget.uploadedTypes.contains(field.name);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        uploaded ? Icons.check_circle_outline : Icons.upload_file_outlined,
        color: uploaded ? Colors.green.shade700 : PartnerColors.primary,
      ),
      title: Text(
        field.required ? '${context.tr(field.label)} *' : context.tr(field.label),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        uploaded ? context.tr('Uploaded') : context.tr('Camera or gallery'),
        style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
      ),
      trailing: widget.readOnly ? null : const Icon(Icons.chevron_right),
      onTap: widget.readOnly ? null : () => widget.onUploadFile(field),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8F9F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PartnerColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PartnerColors.line),
      ),
    );
  }
}

String documentTypeForField(RegistrationField field) {
  final blob = '${field.name} ${field.label}'.toLowerCase();
  if (blob.contains('profile') && blob.contains('photo')) return 'profile_photo';
  if (blob.contains('driving')) return 'driving_licence';
  if (blob.contains('aadhaar') || blob.contains('id proof') || blob.contains('id_proof')) {
    return 'aadhaar';
  }
  if (blob.contains('pan')) return 'pan';
  if (blob.contains('rc')) return 'vehicle_rc';
  if (blob.contains('insurance')) return 'insurance';
  if (blob.contains('gst')) return 'gst_certificate';
  if (blob.contains('bank')) return 'bank_proof';
  if (blob.contains('police')) return 'police_verification';
  if (field.type == 'image') return 'profile_photo';
  return 'other';
}

List<RegistrationField> parseRegistrationFields(Object? formPayload) {
  final form = _asMap(formPayload);
  if (form == null) return [];
  final nested = _asMap(form['data']) ?? form;
  final raw = nested['fields'];
  if (raw is! List) return [];
  final moduleId = int.tryParse('${nested['module_id'] ?? form['module']?['id'] ?? ''}');
  final fields = <RegistrationField>[];
  for (final item in raw) {
    final map = _asMap(item);
    if (map == null) continue;
    final name = map['name']?.toString() ?? '';
    if (name.isEmpty) continue;
    fields.add(
      RegistrationField(
        name: name,
        label: map['label']?.toString() ?? name,
        type: map['type']?.toString() ?? 'text',
        placeholder: map['placeholder']?.toString(),
        helpText: map['help_text']?.toString(),
        required: map['required'] == true || map['is_required'] == true,
        options: _options(map['options']),
        moduleId: moduleId,
      ),
    );
  }
  return fields;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<({String label, String value})> _options(Object? raw) {
  if (raw is! List) return [];
  final options = <({String label, String value})>[];
  for (final item in raw) {
    if (item is String && item.trim().isNotEmpty) {
      options.add((label: item, value: item));
      continue;
    }
    final map = _asMap(item);
    if (map == null) continue;
    final label = map['label']?.toString() ?? map['value']?.toString() ?? '';
    final value = map['value']?.toString() ?? label;
    if (label.isEmpty) continue;
    options.add((label: label, value: value));
  }
  return options;
}
