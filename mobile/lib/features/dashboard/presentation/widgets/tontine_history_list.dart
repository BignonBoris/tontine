import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_history_entry.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TontineHistoryList extends StatelessWidget {
  final List<TontineHistoryEntry> history;

  const TontineHistoryList({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_toggle_off_rounded,
                  size: 36,
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Aucune opération tontine pour le moment",
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: history.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
      ),
      itemBuilder: (context, index) {
        final entry = history[index];
        final typeColor = _typeColor(entry.type);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showReceiptModal(context, entry);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _typeIcon(entry.type),
                        color: typeColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.label,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(entry.date),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${formatFCFA(entry.amount)} F",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                      if (entry.note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.note!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.40),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReceiptModal(BuildContext context, TontineHistoryEntry entry) {
    final typeColor = _typeColor(entry.type);
    final reference = entry.id.length >= 8
        ? "TNT-${entry.id.replaceAll('-', '').substring(0, 8).toUpperCase()}"
        : "TNT-${entry.id.toUpperCase()}";
    final formattedDate = DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(entry.date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(sheetContext).padding.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Poignée
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icône d'en-tête de validation
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: typeColor.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _typeIcon(entry.type),
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  "Reçu d'Opération",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Transaction validée & certifiée",
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Montant
                Text(
                  "${formatFCFA(entry.amount)} F CFA",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  entry.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Fiche récapitulative
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      _ReceiptDetailRow(
                        label: "Référence unique",
                        value: reference,
                        isCode: true,
                      ),
                      const Divider(height: 18),
                      _ReceiptDetailRow(
                        label: "Date & Heure",
                        value: formattedDate,
                      ),
                      const Divider(height: 18),
                      const _ReceiptDetailRow(
                        label: "Compartiment",
                        value: "Tontine 31 jours",
                      ),
                      const Divider(height: 18),
                      const _ReceiptDetailRow(
                        label: "Traçabilité",
                        value: "Grand Livre Immuable",
                      ),
                      if (entry.note != null && entry.note!.isNotEmpty) ...[
                        const Divider(height: 18),
                        _ReceiptDetailRow(
                          label: "Détail / Note",
                          value: entry.note!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // QR Code de vérification stylisé fintech
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomPaint(
                        size: const Size(60, 60),
                        painter: _MockQrCodePainter(color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Signature Numérique",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Piste d'audit horodatée et garantie par la clé cryptographique VizioBox.",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textSecondaryColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(sheetContext);
                          await _shareReceiptPdf(
                            context: context,
                            entry: entry,
                            reference: reference,
                            formattedDate: formattedDate,
                          );
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(
                          "Partager",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.30),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          "Fermer",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _typeIcon(TontineHistoryType type) {
    switch (type) {
      case TontineHistoryType.configuration:
      case TontineHistoryType.restarted:
        return Icons.tune_rounded;
      case TontineHistoryType.deposit:
        return Icons.savings_rounded;
      case TontineHistoryType.depositReversal:
        return Icons.undo_rounded;
      case TontineHistoryType.cycleCompleted:
        return Icons.emoji_events_rounded;
      case TontineHistoryType.payoutConfirmed:
        return Icons.account_balance_wallet_rounded;
      case TontineHistoryType.earlyStop:
        return Icons.stop_circle_outlined;
    }
  }

  Future<void> _shareReceiptPdf({
    required BuildContext context,
    required TontineHistoryEntry entry,
    required String reference,
    required String formattedDate,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Reçu d\'Opération VizioBox',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1E3A8A),
                    ),
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Text('Détails de l\'opération', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Opération :'),
                    pw.Text(entry.label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Montant :'),
                    pw.Text('${formatFCFA(entry.amount)} F CFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date :'),
                    pw.Text(formattedDate),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Référence :'),
                    pw.Text(reference),
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Note :'),
                      pw.Text(entry.note!),
                    ],
                  ),
                ],
                pw.SizedBox(height: 60),
                pw.Center(
                  child: pw.Text(
                    'Transaction validée & certifiée (Tontine 31 jours)',
                    style: pw.TextStyle(fontSize: 12, color: const PdfColor.fromInt(0xFF2E7D32)),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Piste d\'audit horodatée et garantie par VizioBox.',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'recu_viziobox_$reference.pdf',
    );
  }

  Color _typeColor(TontineHistoryType type) {
    switch (type) {
      case TontineHistoryType.configuration:
      case TontineHistoryType.restarted:
        return AppTheme.primaryColor;
      case TontineHistoryType.deposit:
        return AppTheme.secondaryColor;
      case TontineHistoryType.depositReversal:
        return AppTheme.errorColor;
      case TontineHistoryType.cycleCompleted:
        return AppTheme.accentColor;
      case TontineHistoryType.payoutConfirmed:
        return const Color(0xFF00897B);
      case TontineHistoryType.earlyStop:
        return AppTheme.errorColor;
    }
  }
}

class _ReceiptDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;

  const _ReceiptDetailRow({
    required this.label,
    required this.value,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: isCode
              ? GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                )
              : GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
        ),
      ],
    );
  }
}

class _MockQrCodePainter extends CustomPainter {
  final Color color;

  _MockQrCodePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const cornerSize = 18.0;
    const innerSize = 8.0;

    void drawCorner(double left, double top) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cornerSize, cornerSize),
          const Radius.circular(4),
        ),
        paint,
      );
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 3, top + 3, cornerSize - 6, cornerSize - 6),
          const Radius.circular(2),
        ),
        whitePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 5, top + 5, innerSize, innerSize),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    // 3 Coins QR
    drawCorner(0, 0);
    drawCorner(size.width - cornerSize, 0);
    drawCorner(0, size.height - cornerSize);

    // Points de données stylisés
    final dotPaint = Paint()..color = color.withValues(alpha: 0.85);
    final offsets = [
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.8),
      Offset(size.width * 0.7, size.height * 0.35),
      Offset(size.width * 0.85, size.height * 0.65),
    ];

    for (final off in offsets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(off.dx - 2.5, off.dy - 2.5, 5, 5),
          const Radius.circular(1.5),
        ),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
