import 'package:flutter/material.dart';

/// Associe l’icône stockée en base (Material name) à une [IconData].
IconData categoryIconFromKey(String? key) {
  switch (key) {
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'cleaning_services':
      return Icons.cleaning_services_rounded;
    case 'yard':
      return Icons.yard_outlined;
    case 'plumbing':
      return Icons.plumbing_rounded;
    case 'electrical_services':
      return Icons.electrical_services_rounded;
    case 'security':
      return Icons.security_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Fallback par nom de catégorie (utile si `icone` est vide).
IconData categoryIconFromName(String nom) {
  final n = nom.toLowerCase();
  if (n.contains('cuisin')) return Icons.restaurant_rounded;
  if (n.contains('ménag')) return Icons.cleaning_services_rounded;
  if (n.contains('jardin')) return Icons.yard_outlined;
  if (n.contains('plomb')) return Icons.plumbing_rounded;
  if (n.contains('électr') || n.contains('electr')) return Icons.electrical_services_rounded;
  if (n.contains('sécur') || n.contains('secur')) return Icons.security_rounded;
  return Icons.home_repair_service_rounded;
}
