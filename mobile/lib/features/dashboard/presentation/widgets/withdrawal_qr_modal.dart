import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/domain/entities/withdrawal_request_result.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Modal affichant le QR Code d'un retrait agent_cash.
/// Le QR encode la référence du retrait (ex: WDR-XXXX-XXXX).
/// L'agent scanne ce code pour retrouver automatiquement le retrait,
/// comme s'il avait saisi manuellement la référence.
class WithdrawalQrModal extends StatelessWidget {
  final WithdrawalRequestResult result;

  const WithdrawalQrModal({super.key, required this.result});

  static Future<void> show(
    BuildContext context,
    WithdrawalRequestResult result,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WithdrawalQrModal(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = result.confirmationCodeExpiresAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Poignée ────────────────────────────────────────────────────
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // ── Titre ──────────────────────────────────────────────────────
          Text(
            'QR Code de retrait',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Présentez ce QR code à votre agent collecteur\npour valider votre retrait.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // ── Cadre QR ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // QR Code réel
                QrImageView(
                  data: result.reference,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.primaryColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 14),

                // Référence texte
                Text(
                  result.reference,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),

                // Montant
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_formatFcfa(result.amount)} FCFA',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondaryVariantColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Expiration (si applicable) ─────────────────────────────────
          if (expiresAt != null) ...[
            _ExpiryBadge(expiresAt: expiresAt),
            const SizedBox(height: 8),
          ],

          // ── Info sécurité ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF1565C0),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ce QR code est à usage unique. Ne le partagez qu\'avec votre agent collecteur.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Bouton Fermer ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Fermer',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFcfa(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount.toInt());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget d'expiration avec compte à rebours
// ─────────────────────────────────────────────────────────────────────────────
class _ExpiryBadge extends StatefulWidget {
  final DateTime expiresAt;

  const _ExpiryBadge({required this.expiresAt});

  @override
  State<_ExpiryBadge> createState() => _ExpiryBadgeState();
}

class _ExpiryBadgeState extends State<_ExpiryBadge> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expiresAt.difference(DateTime.now());
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remaining = widget.expiresAt.difference(DateTime.now());
      });
      if (_remaining.isNegative) return;
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining.isNegative;
    final minutes = _remaining.inMinutes.abs();
    final seconds = (_remaining.inSeconds.abs() % 60).toString().padLeft(2, '0');
    final label = isExpired ? 'Expiré' : 'Expire dans ${minutes}m${seconds}s';
    final color = isExpired
        ? const Color(0xFFB71C1C)
        : (_remaining.inMinutes < 5 ? const Color(0xFFE65100) : const Color(0xFF2E7D32));
    final bg = isExpired
        ? const Color(0xFFFFEBEE)
        : (_remaining.inMinutes < 5 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
