import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Badge « Prestataire vérifié » (admin).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const Tooltip(
        message: 'Prestataire vérifié par ServiDom',
        child: Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
      );
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      avatar: const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
      label: const Text('Vérifié', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
    );
  }
}
