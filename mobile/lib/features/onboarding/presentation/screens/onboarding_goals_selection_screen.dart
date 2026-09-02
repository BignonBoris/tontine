import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/onboarding/data/services/goal_templates_service.dart';
import 'package:mobile/features/onboarding/domain/entities/goal_template.dart';

class OnboardingGoalsSelectionScreen extends StatefulWidget {
  static bool hasPromptedThisSession = false;

  const OnboardingGoalsSelectionScreen({super.key});

  @override
  State<OnboardingGoalsSelectionScreen> createState() =>
      _OnboardingGoalsSelectionScreenState();
}

class _OnboardingGoalsSelectionScreenState
    extends State<OnboardingGoalsSelectionScreen> {
  final GoalTemplatesService _service = GoalTemplatesService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<GoalTemplate> _templates = [];
  final Set<String> _selectedTemplateIds = {};

  static const int _maxSelection = 3;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.fetchActiveTemplates();

      if (!mounted) return;

      setState(() {
        _templates = response.templates;
        _isLoading = false;

        // Pré-sélectionner par défaut le 1er template pour inciter à l'action
        if (_templates.isNotEmpty && _selectedTemplateIds.isEmpty) {
          _selectedTemplateIds.add(_templates.first.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _templates = GoalTemplate.fallbackTemplates;
        _isLoading = false;
        if (_templates.isNotEmpty && _selectedTemplateIds.isEmpty) {
          _selectedTemplateIds.add(_templates.first.id);
        }
      });
    }
  }

  void _toggleTemplate(GoalTemplate template) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTemplateIds.contains(template.id)) {
        _selectedTemplateIds.remove(template.id);
      } else {
        if (_selectedTemplateIds.length >= _maxSelection) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vous pouvez choisir jusqu\'à $_maxSelection boxs d\'épargne.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedTemplateIds.add(template.id);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedTemplateIds.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    try {
      await _service.applyTemplates(_selectedTemplateIds.toList());

      if (!mounted) return;

      // Transition directe vers le tableau de bord
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
        arguments: {'skip_onboarding': true},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Impossible d\'enregistrer vos choix. Réessayez ou passez.';
      });
    }
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/dashboard',
      (route) => false,
      arguments: {'skip_onboarding': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedTemplateIds.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER VizioBox ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge étape
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppTheme.accentColor,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Personnalisation • 1 à 3 boxs',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bouton Passer
                      TextButton(
                        onPressed: _isSubmitting ? null : _handleSkip,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          foregroundColor: Colors.white.withValues(alpha: 0.8),
                        ),
                        child: Text(
                          'Passer',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choisissez vos premiers projets',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sélectionnez 1 à 3 boxs pour préparer votre tableau de bord. Vous pourrez les modifier à tout moment.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // --- CORPS BLANC AVEC LISTE DES BOXS ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Column(
                        children: [
                          // Barre d'état de sélection
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Projets disponibles (${_templates.length})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasSelection
                                        ? AppTheme.accentDarkColor
                                            .withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedTemplateIds.length} / $_maxSelection sélectionnée${_selectedTemplateIds.length > 1 ? 's' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: hasSelection
                                          ? AppTheme.accentDarkColor
                                          : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFB91C1C),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Liste défilable des modèles de box
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              itemCount: _templates.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final template = _templates[index];
                                final isSelected =
                                    _selectedTemplateIds.contains(template.id);

                                return _buildTemplateCard(
                                  template: template,
                                  isSelected: isSelected,
                                  onTap: () => _toggleTemplate(template),
                                );
                              },
                            ),
                          ),

                          // --- FOOTER & BOUTON CTA ---
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: hasSelection && !_isSubmitting
                                        ? AppTheme.accentGradient
                                        : null,
                                    color: hasSelection && !_isSubmitting
                                        ? null
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: hasSelection && !_isSubmitting
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.accentDarkColor
                                                  .withValues(alpha: 0.30),
                                              blurRadius: 14,
                                              offset: const Offset(0, 5),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: hasSelection && !_isSubmitting
                                        ? _handleSubmit
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                hasSelection
                                                    ? 'Valider mes ${_selectedTemplateIds.length} box${_selectedTemplateIds.length > 1 ? 's' : ''}'
                                                    : 'Sélectionnez au moins 1 box',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: hasSelection
                                                      ? Colors.white
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              if (hasSelection) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 13,
                                      color: AppTheme.textSecondaryColor
                                          .withValues(alpha: 0.70),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Création gratuite • Modifiable à tout moment',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textSecondaryColor
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard({
    required GoalTemplate template,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentDarkColor
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.accentDarkColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône personnalisée avec sa couleur de modèle
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: template.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: template.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  template.iconData,
                  color: template.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Contenu textuel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (template.description != null &&
                        template.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        template.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (template.defaultTargetAmount != null &&
                        template.defaultTargetAmount! > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cible : ${formatFCFA(template.defaultTargetAmount!)} FCFA',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Coche de sélection
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected ? AppTheme.accentGradient : null,
                  color: isSelected ? null : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : const Color(0xFFCBD5E1),
                    width: 1.8,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
