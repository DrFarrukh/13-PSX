/// Reusable section wrapper with a title and optional subtitle.
library;

import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1a3a5c),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
