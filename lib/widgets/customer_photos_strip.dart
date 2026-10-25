import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';

/// Thumbnails of photos the customer attached while booking.
class CustomerPhotosStrip extends StatelessWidget {
  const CustomerPhotosStrip({super.key, required this.urls, this.title = 'Customer photo'});

  final List<String> urls;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_outlined, size: 16, color: PartnerColors.primary),
            const SizedBox(width: 6),
            Text(context.tr(title), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openViewer(context, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  urls[i],
                  width: 96,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 96,
                    height: 72,
                    color: PartnerColors.chip,
                    child: const Icon(Icons.broken_image_outlined, color: PartnerColors.muted),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, int initial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(context.tr(title)),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(child: Image.network(urls[i], fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }
}
