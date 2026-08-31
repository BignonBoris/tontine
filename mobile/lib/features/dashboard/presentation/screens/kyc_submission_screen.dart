import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:mobile/features/dashboard/presentation/widgets/finance_hero_header.dart';

class KycSubmissionScreen extends StatefulWidget {
  final KycSummary currentStatus;

  const KycSubmissionScreen({super.key, required this.currentStatus});

  @override
  State<KycSubmissionScreen> createState() => _KycSubmissionScreenState();
}

class _KycSubmissionScreenState extends State<KycSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumberController = TextEditingController();
  final _apiClient = ApiClient();
  final _imagePicker = ImagePicker();
  
  String _documentType = 'cni';
  bool _isSubmitting = false;
  XFile? _documentImage;
  Uint8List? _documentBytes;

  @override
  void dispose() {
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documentImage == null || _documentBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez une photo lisible du document.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final contentType = _documentImage!.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      await _apiClient.postBytes(
        '/kyc/documents?documentType=$_documentType&countryCode=BJ&documentNumber=${Uri.encodeQueryComponent(_documentNumberController.text.trim())}',
        bytes: _documentBytes!,
        contentType: contentType,
      );
      if (!mounted) return;
      context.read<DashboardBloc>().add(LoadDashboardData());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre dossier est en cours de revue.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2200,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _documentImage = image;
          _documentBytes = bytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.currentStatus.status == 'pending_review';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const FinanceHeroHeader(
            title: 'Vérification KYC',
            subtitle: 'Conformité & identité certifiée',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusHeaderCard(status: widget.currentStatus),
                    const SizedBox(height: 26),
                    Text(
                      'Pièce d\'identité',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                const SizedBox(height: 6),
                Text(
                  'Renseignez les informations de votre document officiel émis au Bénin pour lever vos restrictions de retrait.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _documentType,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Type de document',
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'cni',
                      child: Text('Carte nationale d\'identité (CNI / CIP)'),
                    ),
                    DropdownMenuItem(
                      value: 'passport',
                      child: Text('Passeport international'),
                    ),
                    DropdownMenuItem(
                      value: 'residence_permit',
                      child: Text('Carte de séjour / Résidence'),
                    ),
                  ],
                  onChanged: pending
                      ? null
                      : (value) => setState(() => _documentType = value ?? 'cni'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _documentNumberController,
                  enabled: !pending,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppTheme.textPrimaryColor,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Numéro du document',
                    hintText: 'Ex. BJ123456',
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().length < 4
                      ? 'Saisissez un numéro valide'
                      : null,
                ),
                const SizedBox(height: 26),
                Text(
                  'Photo du document',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                _InteractiveCaptureArea(
                  isPending: pending,
                  documentImage: _documentImage,
                  documentBytes: _documentBytes,
                  onTap: _pickDocument,
                  onClear: () {
                    setState(() {
                      _documentImage = null;
                      _documentBytes = null;
                    });
                  },
                ),
                const SizedBox(height: 28),
                _TrustReassuranceCard(),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: pending || _isSubmitting ? null : AppTheme.accentGradient,
                    color: pending || _isSubmitting ? AppTheme.borderColor : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: pending || _isSubmitting
                        ? null
                        : [
                            BoxShadow(
                              color: AppTheme.accentColor.withOpacity(0.24),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: pending || _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Soumettre le dossier',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (pending) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Votre dossier est déjà en cours de traitement.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
}
}

class _StatusHeaderCard extends StatelessWidget {
  final KycSummary status;

  const _StatusHeaderCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final verified = status.status == 'verified';
    final pending = status.status == 'pending_review';
    final rejected = status.status == 'rejected';

    Color startColor;
    Color endColor;
    Color contentColor;
    String title;
    String subtitle;
    IconData icon;

    if (verified) {
      startColor = const Color(0xFF1B5E20);
      endColor = const Color(0xFF2E7D32);
      contentColor = Colors.white;
      title = 'Identité Vérifiée';
      subtitle = 'Votre compte est pleinement opérationnel. Limites débloquées.';
      icon = Icons.verified_rounded;
    } else if (pending) {
      startColor = const Color(0xFFE65100);
      endColor = const Color(0xFFEF6C00);
      contentColor = Colors.white;
      title = 'Dossier en Cours de Revue';
      subtitle = 'Nos agents vérifient vos documents. Cela prend moins de 24h.';
      icon = Icons.hourglass_top_rounded;
    } else if (rejected) {
      startColor = const Color(0xFFB71C1C);
      endColor = const Color(0xFFC62828);
      contentColor = Colors.white;
      title = 'Dossier Rejeté';
      subtitle = status.rejectionReason ?? 'Les pièces fournies sont illisibles ou incorrectes. Veuillez soumettre à nouveau.';
      icon = Icons.error_outline_rounded;
    } else {
      startColor = AppTheme.primaryColor;
      endColor = AppTheme.primaryVariantColor;
      contentColor = Colors.white;
      title = 'Compte non vérifié';
      subtitle = 'Soumettez vos justificatifs pour valider votre compte VizioBox.';
      icon = Icons.shield_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: contentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: contentColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: contentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: contentColor.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveCaptureArea extends StatelessWidget {
  final bool isPending;
  final XFile? documentImage;
  final Uint8List? documentBytes;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _InteractiveCaptureArea({
    required this.isPending,
    required this.documentImage,
    required this.documentBytes,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (documentImage != null && documentBytes != null) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.successColor.withOpacity(0.4), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                documentBytes!,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Photo capturée',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isPending)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Reprendre'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.textPrimaryColor,
                            minimumSize: const Size(0, 42),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: isPending ? null : onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: isPending ? AppTheme.borderColor : AppTheme.accentColor.withOpacity(0.6),
          borderRadius: 20,
        ),
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_enhance_outlined,
                  color: AppTheme.accentColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Photographier le document',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cadrez la face avant et évitez les reflets.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustReassuranceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            color: AppTheme.primaryColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sécurisé et Conforme APDP',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vos documents d\'identité sont chiffrés de bout en bout et traités conformément aux dispositions de l\'APDP au Bénin et des réglementations BCEAO.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.45,
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.4,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    double distance = 0.0;
    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        final double len = dashWidth;
        dashPath.addPath(
          measurePath.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += len + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
