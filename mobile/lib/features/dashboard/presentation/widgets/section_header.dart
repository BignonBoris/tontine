import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onActionPressed;
  final String actionLabel; // Paramètre ajouté pour personnaliser le texte
  final IconData? icon; // Paramètre optionnel pour changer l'icône

  const SectionHeader({
    super.key,
    required this.title,
    required this.onActionPressed,
    this.actionLabel = "Faire un dépôt", // Valeur par défaut
    this.icon, // Optionnel
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A237E),
          ),
        ),
        TextButton.icon(
          onPressed: onActionPressed,
          // Utilise l'icône fournie, sinon utilise l'icône par défaut
          icon: Icon(
            icon ?? Icons.add_circle_outline,
            size: 18,
            color: const Color(0xFFFFAB00),
          ),
          label: Text(
            actionLabel, // Utilise le label passé en paramètre
            style: GoogleFonts.inter(
              color: const Color(0xFFFFAB00),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
