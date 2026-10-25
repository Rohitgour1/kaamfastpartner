import 'package:flutter/material.dart';

class PartnerWorkType {
  const PartnerWorkType({
    required this.id,
    required this.title,
    required this.slug,
    required this.moduleSlug,
    required this.description,
    this.moduleId,
    this.serviceId,
    this.icon = Icons.handyman_outlined,
    this.isModule = false,
  });

  final String id;
  final String title;
  final String slug;
  final String moduleSlug;
  final String description;
  final int? moduleId;
  final int? serviceId;
  final IconData icon;
  final bool isModule;

  static IconData iconFor(String slug, [String? title]) {
    final key = '${slug}_${title ?? ''}'.toLowerCase();
    if (key.contains('clean')) return Icons.cleaning_services_outlined;
    if (key.contains('electric')) return Icons.electrical_services_outlined;
    if (key.contains('labour') || key.contains('labor')) return Icons.fitness_center_outlined;
    if (key.contains('moving') || key.contains('shift')) return Icons.local_shipping_outlined;
    if (key.contains('shop')) return Icons.shopping_bag_outlined;
    if (key.contains('assist') || key.contains('household')) return Icons.handshake_outlined;
    if (key.contains('helper')) return Icons.handyman_outlined;
    if (key.contains('laundry')) return Icons.local_laundry_service_outlined;
    if (key.contains('parcel') || key.contains('deliver')) return Icons.delivery_dining_outlined;
    return Icons.miscellaneous_services_outlined;
  }

  static List<PartnerWorkType> fallbackForServicePartner() => const [
        PartnerWorkType(
          id: 'cleaning',
          title: 'Cleaner',
          slug: 'cleaning',
          moduleSlug: 'cleaning',
          description: 'Home, deep, kitchen and bathroom cleaning jobs.',
          icon: Icons.cleaning_services_outlined,
        ),
        PartnerWorkType(
          id: 'helper-electrician',
          title: 'Electrician',
          slug: 'electrician',
          moduleSlug: 'helper',
          description: 'Fans, wiring, switches and electrical repairs.',
          icon: Icons.electrical_services_outlined,
        ),
        PartnerWorkType(
          id: 'helper-labour',
          title: 'Labour',
          slug: 'labour',
          moduleSlug: 'helper',
          description: 'Loading, unloading and heavy household work.',
          icon: Icons.fitness_center_outlined,
        ),
        PartnerWorkType(
          id: 'helper-assistant',
          title: 'Assistant',
          slug: 'assistant',
          moduleSlug: 'helper',
          description: 'On-demand household help by the hour.',
          icon: Icons.handshake_outlined,
        ),
        PartnerWorkType(
          id: 'helper-moving',
          title: 'Moving help',
          slug: 'moving',
          moduleSlug: 'helper',
          description: 'Packing, shifting and moving assistance.',
          icon: Icons.local_shipping_outlined,
        ),
        PartnerWorkType(
          id: 'helper-general',
          title: 'General Helper',
          slug: 'helper',
          moduleSlug: 'helper',
          description: 'Flexible helper jobs for everyday household tasks.',
          icon: Icons.handyman_outlined,
        ),
      ];

  /// Service partners pick work types from service modules.
  /// Helper is expanded into electrician / labour / etc.
  static List<PartnerWorkType> fromModules(List<Map<String, dynamic>> modules, {required String partnerType}) {
    final items = <PartnerWorkType>[];
    for (final module in modules) {
      final types = (module['provider_types'] as List? ?? []).map((e) => e.toString()).toList();
      if (!types.contains(partnerType)) continue;

      final moduleSlug = module['slug']?.toString() ?? '';
      final moduleId = module['id'] is int ? module['id'] as int : int.tryParse('${module['id']}');
      final services = module['services'];

      if (moduleSlug == 'helper' && services is List && services.isNotEmpty) {
        for (final raw in services) {
          if (raw is! Map) continue;
          final service = Map<String, dynamic>.from(raw);
          final name = service['name']?.toString() ?? 'Helper';
          final slug = service['slug']?.toString().isNotEmpty == true
              ? service['slug'].toString()
              : name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
          items.add(PartnerWorkType(
            id: 'helper-$slug',
            title: name,
            slug: slug,
            moduleSlug: moduleSlug,
            moduleId: moduleId,
            serviceId: service['id'] is int ? service['id'] as int : int.tryParse('${service['id']}'),
            description: '',
            icon: iconFor(slug, name),
          ));
        }
        continue;
      }

      final name = moduleSlug == 'cleaning' ? 'Cleaner' : (module['name']?.toString() ?? moduleSlug);
      items.add(PartnerWorkType(
        id: moduleSlug,
        title: name,
        slug: moduleSlug,
        moduleSlug: moduleSlug,
        moduleId: moduleId,
        description: module['short_description']?.toString().trim() ?? '',
        icon: iconFor(moduleSlug, name),
        isModule: true,
      ));
    }
    return items.isEmpty ? fallbackForServicePartner() : items;
  }
}
