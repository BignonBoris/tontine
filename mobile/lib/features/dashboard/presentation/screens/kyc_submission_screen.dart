import 'dart:io';
import 'dart:typed_data';
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
import 'package:mobile/features/kyc/presentation/widgets/document_capture_card.dart';
import 'package:mobile/features/kyc/presentation/widgets/selfie_capture_card.dart';

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
  
  String _documentType = 'cni';
  bool _isSubmitting = false;

  File? _documentFront;
  File? _documentBack;
  File? _selfie;

  @override
  void dispose() {
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_documentFront == null || _selfie == null || (_documentType != 'passport' && _documentBack == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez fournir tous les documents requis et un selfie.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Simulate real file reading and upload
      final frontBytes = await _documentFront!.readAsBytes();
      
      final contentType = _documentFront!.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
          
      await _apiClient.postBytes(
        '/kyc/documents?documentType=$_documentType&countryCode=BJ&documentNumber=${Uri.encodeQueryComponent(_documentNumberController.text.trim())}',
        bytes: frontBytes, // In a real scenario, use multipart to send front, back and selfie
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
            content: Text("Erreur de connexion. Veuillez réessayer."),
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

  @override
  Widget build(BuildContext context) {
    final pending = widget.currentStatus.status == 'pending_review';
    final verified = widget.currentStatus.status == 'verified';
    final disabled = pending || verified;

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
                      onChanged: disabled
                          ? null
                          : (value) => setState(() {
                              _documentType = value ?? 'cni';
                              if (_documentType == 'passport') {
                                _documentBack = null;
                              }
                            }),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _documentNumberController,
                      enabled: !disabled,
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
                    if (!verified) ...[
                      DocumentCaptureCard(
                        title: "Photo du Recto",
                        description: "Vérifiez que les textes sont lisibles et qu'il n'y a pas de reflet.",
                        initialImage: _documentFront,
                        onImageCaptured: disabled ? (f) {} : (file) {
                          setState(() => _documentFront = file);
                        },
                        onImageRemoved: disabled ? null : () {
                          setState(() => _documentFront = null);
                        },
                      ),
                      if (_documentType != 'passport')
                        DocumentCaptureCard(
                          title: "Photo du Verso",
                          description: "Capturez le dos de votre pièce d'identité.",
                          initialImage: _documentBack,
                          onImageCaptured: disabled ? (f) {} : (file) {
                            setState(() => _documentBack = file);
                          },
                          onImageRemoved: disabled ? null : () {
                            setState(() => _documentBack = null);
                          },
                        ),
                      const SizedBox(height: 16),
                      SelfieCaptureCard(
                        initialImage: _selfie,
                        onImageCaptured: disabled ? (f) {} : (file) {
                          setState(() => _selfie = file);
                        },
                        onImageRemoved: disabled ? null : () {
                          setState(() => _selfie = null);
                        },
                      ),
                    ],
                    const SizedBox(height: 28),
                    _TrustReassuranceCard(),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: disabled || _isSubmitting ? null : AppTheme.accentGradient,
                        color: disabled || _isSubmitting ? AppTheme.borderColor : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: disabled || _isSubmitting
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
                        onPressed: disabled || _isSubmitting ? null : _submit,
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
