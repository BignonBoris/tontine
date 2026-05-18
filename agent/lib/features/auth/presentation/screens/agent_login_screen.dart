import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/features/auth/data/services/agent_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key});

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AgentAuthService();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgentAppTheme.primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: 460,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  AgentAppTheme.accentColor.withValues(alpha: 0.18),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AgentAppTheme.accentDarkColor.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Image.asset(AgentAppTheme.brandIconAsset),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'VizioBox Agent',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Espace Agent',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Connectez-vous pour enregistrer les operations terrain et suivre vos activites du jour.",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 34),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: AgentInputRules.phoneFormatters,
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Numero agent',
                                  hintText: 'Ex. 01 23 45 67 89',
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      !AgentInputRules.isValidPhone(value)) {
                                    return 'Entrez un numero valide';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _pinController,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: AgentInputRules.pinFormatters,
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Code PIN agent',
                                  hintText: '4 chiffres',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().length != 4) {
                                    return 'Entrez votre PIN';
                                  }
                                  return null;
                                },
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _InlineAuthMessage(
                                  message: _errorMessage!,
                                  onClose: () {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  },
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _submit(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AgentAppTheme.accentColor,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Se connecter'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Center(
                        child: Text(
                          "Seuls les agents autorises peuvent acceder aux operations terrain.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.70),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _authService.login(
        phoneNumber: AgentInputRules.normalizePhone(_phoneController.text),
        pin: _pinController.text.trim(),
      );
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError("La connexion agent a echoue. Reessayez dans un instant.");
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
  }
}

class _InlineAuthMessage extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _InlineAuthMessage({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB91C1C),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB91C1C),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                color: Color(0xFFB91C1C),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
