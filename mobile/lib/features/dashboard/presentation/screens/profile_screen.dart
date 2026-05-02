import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/profile_metric_card.dart';
import 'package:mobile/features/dashboard/presentation/widgets/profile_section_tile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Mon Profil",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              final unreadCount = state is DashboardLoaded
                  ? state.notifications.where((item) => !item.isRead).length
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<DashboardBloc>(),
                              child: const NotificationsScreen(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardError) {
            return DashboardErrorView(
              title: state.title,
              message: state.message,
              inline: true,
              requiresReauthentication: state.requiresReauthentication,
            );
          }

          if (state is! DashboardLoaded) {
            return const DashboardLoadingView(
              label: "Chargement du profil...",
              inline: true,
            );
          }

          final activeGoals = state.goals
              .where((goal) => goal.status == GoalStatus.active)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeroCard(
                  profile: state.profile,
                  tontineCycle: state.tontineCycle,
                  availableBalance: state.availableBalance,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ProfileMetricCard(
                        icon: Icons.lock_outline_rounded,
                        label: "Mise actuelle",
                        value: state.tontineCycle == null
                            ? "Aucune"
                            : "${formatFCFA(state.tontineCycle!.stakeAmount)} F",
                        iconBackgroundColor: AppTheme.primaryColor.withOpacity(
                          0.10,
                        ),
                        iconColor: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProfileMetricCard(
                        icon: Icons.flag_rounded,
                        label: "Coffres actifs",
                        value: "${activeGoals.length}",
                        iconBackgroundColor: AppTheme.secondaryColor
                            .withOpacity(0.12),
                        iconColor: AppTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProfileMetricCard(
                        icon: Icons.shopping_bag_outlined,
                        label: "Commandes",
                        value: "${state.marketOrders.length}",
                        iconBackgroundColor: AppTheme.accentColor.withOpacity(
                          0.18,
                        ),
                        iconColor: const Color(0xFF8A5B00),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  "Parametres du compte",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                ProfileSectionTile(
                  icon: Icons.person_outline_rounded,
                  title: "Informations personnelles",
                  subtitle:
                      "Modifier votre nom, votre numero et voir vos details",
                  iconBackgroundColor: AppTheme.primaryColor.withOpacity(0.10),
                  iconColor: AppTheme.primaryColor,
                  onTap: () => _showProfileEditor(context, state),
                ),
                ProfileSectionTile(
                  icon: Icons.notifications_none_rounded,
                  title: "Notifications",
                  subtitle:
                      "Regler les alertes depots, cycles et messages produit",
                  iconBackgroundColor: AppTheme.secondaryColor.withOpacity(
                    0.12,
                  ),
                  iconColor: AppTheme.secondaryColor,
                  onTap: () => _showNotificationSettings(context, state),
                ),
                ProfileSectionTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: "Centre de notifications",
                  subtitle:
                      "${state.notifications.where((item) => !item.isRead).length} non lues dans votre historique",
                  iconBackgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                  iconColor: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<DashboardBloc>(),
                          child: const NotificationsScreen(),
                        ),
                      ),
                    );
                  },
                ),
                ProfileSectionTile(
                  icon: Icons.verified_user_outlined,
                  title: "Securite",
                  subtitle: "Configurer PIN local et validation biometrique",
                  iconBackgroundColor: AppTheme.accentColor.withOpacity(0.18),
                  iconColor: const Color(0xFF8A5B00),
                  onTap: () => _showSecuritySettings(context, state),
                ),
                ProfileSectionTile(
                  icon: Icons.help_outline_rounded,
                  title: "FAQ",
                  subtitle:
                      "Questions frequentes sur la tontine et les coffres",
                  iconBackgroundColor: Colors.grey.shade100,
                  iconColor: Colors.grey.shade700,
                  onTap: () => _showFAQ(context),
                ),
                ProfileSectionTile(
                  icon: Icons.support_agent_rounded,
                  title: "Aide & support",
                  subtitle: "WhatsApp, email et numero d'assistance",
                  iconBackgroundColor: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF2E7D32),
                  onTap: () => _showSupport(context),
                ),
                const SizedBox(height: 8),
                ProfileSectionTile(
                  icon: Icons.logout_rounded,
                  title: "Deconnexion",
                  subtitle: "Quitter la session actuelle",
                  iconBackgroundColor: const Color(0xFFFFEBEE),
                  iconColor: AppTheme.errorColor,
                  isDanger: true,
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await LocalSecurityService.clear();
    await SessionStorage.clear();
    if (!context.mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/auth_choice',
      (route) => false,
    );
  }

  void _showProfileEditor(BuildContext context, DashboardLoaded state) {
    final nameController = TextEditingController(
      text: state.profile.displayName,
    );
    final phoneController = TextEditingController(
      text: state.profile.phoneNumber,
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Informations personnelles",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nom affiche",
                  hintText: "Votre nom visible dans l'application",
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return "Entrez un nom valide";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Numero de telephone",
                  hintText: "+229 00 00 00 00",
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 8) {
                    return "Entrez un numero valide";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow("Type de compte", state.profile.accountType),
                    _buildInfoRow(
                      "Membre depuis",
                      _formatLongMonth(state.profile.memberSince),
                    ),
                    _buildInfoRow(
                      "Derniere connexion",
                      state.profile.lastLoginAt == null
                          ? "Premiere connexion"
                          : DateFormat(
                              'dd/MM/yyyy HH:mm',
                              'fr_FR',
                            ).format(state.profile.lastLoginAt!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final updatedProfile = state.profile.copyWith(
                      displayName: nameController.text.trim(),
                      phoneNumber: phoneController.text.trim(),
                    );
                    context.read<DashboardBloc>().add(
                      SaveUserProfile(updatedProfile),
                    );
                    Navigator.pop(sheetContext);
                  },
                  child: const Text("Enregistrer les modifications"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context, DashboardLoaded state) {
    var preferences = state.preferences;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notifications",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _PreferenceSwitchTile(
                  title: "Alertes de depot",
                  subtitle:
                      "Recevoir des rappels pour vos versements et depots",
                  value: preferences.depositNotificationsEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      preferences = preferences.copyWith(
                        depositNotificationsEnabled: value,
                      );
                    });
                  },
                ),
                _PreferenceSwitchTile(
                  title: "Fin de cycle tontine",
                  subtitle: "Etre averti quand un cycle atteint son objectif",
                  value: preferences.cycleNotificationsEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      preferences = preferences.copyWith(
                        cycleNotificationsEnabled: value,
                      );
                    });
                  },
                ),
                _PreferenceSwitchTile(
                  title: "Messages produit",
                  subtitle:
                      "Recevoir les nouveaux articles et promotions utiles",
                  value: preferences.marketingNotificationsEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      preferences = preferences.copyWith(
                        marketingNotificationsEnabled: value,
                      );
                    });
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<DashboardBloc>().add(
                        SaveProfilePreferences(preferences),
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text("Enregistrer"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSecuritySettings(
    BuildContext context,
    DashboardLoaded state,
  ) async {
    final localSettings = await LocalSecurityService.loadSettings();
    if (!context.mounted) {
      return;
    }

    var pinEnabled = localSettings.pinEnabled;
    var biometricEnabled = localSettings.biometricEnabled;
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Securite locale",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _PreferenceSwitchTile(
                  title: "Activer un code PIN",
                  subtitle: "Ajouter un code local pour proteger l'acces",
                  value: pinEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      pinEnabled = value;
                    });
                  },
                ),
                if (pinEnabled) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Code PIN",
                      hintText: "4 chiffres",
                    ),
                    validator: (value) {
                      if (!pinEnabled) {
                        return null;
                      }
                      if (!localSettings.pinEnabled &&
                          (value == null || value.trim().length != 4)) {
                        return "Entrez un PIN a 4 chiffres";
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 10),
                _PreferenceSwitchTile(
                  title: "Validation biometrie",
                  subtitle:
                      "Activer la validation locale si l'appareil le permet",
                  value: biometricEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      biometricEnabled = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      if (localSettings.pinEnabled) {
                        final authorized =
                            await LocalSecurityService.authorizeIfEnabled(
                              context,
                              title: 'Modifier la securite',
                              message:
                                  "Entrez votre PIN actuel pour modifier les parametres de securite.",
                            );
                        if (!context.mounted || !authorized) {
                          return;
                        }
                      }

                      await LocalSecurityService.saveSettings(
                        pinEnabled: pinEnabled,
                        biometricEnabled: biometricEnabled,
                        pinCode: pinController.text.trim(),
                        clearPin: !pinEnabled,
                      );

                      final updatedPreferences = state.preferences.copyWith(
                        pinEnabled: pinEnabled,
                        biometricEnabled: biometricEnabled,
                        clearPinCode: true,
                      );
                      context.read<DashboardBloc>().add(
                        SaveProfilePreferences(updatedPreferences),
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text("Enregistrer"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        maxChildSize: 0.82,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Questions frequentes",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildFAQItem(
                      "Comment fonctionne un coffre ?",
                      "Un coffre vous permet de mettre de l'argent de cote pour un objectif precis. Vous pouvez y faire plusieurs depots depuis le solde disponible puis le cloturer quand vous le souhaitez.",
                    ),
                    _buildFAQItem(
                      "Puis-je retirer mon argent avant ?",
                      "Pour la tontine, un arret avant la fin du cycle applique une penalite egale a une mise. Pour un coffre, la cloture renvoie l'integralite du montant sur le solde disponible.",
                    ),
                    _buildFAQItem(
                      "Comment se termine un cycle de tontine ?",
                      "Quand le cumul atteint l'objectif de 31 mises, vous confirmez le reversement vers le solde disponible. La commission de la plateforme est egale a une mise.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aide & support",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.chat_bubble_outline, color: Colors.green),
              ),
              title: const Text("WhatsApp support"),
              subtitle: const Text("+229 01 00 00 00 00"),
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: '+229 01 00 00 00 00'),
                );
                Navigator.pop(sheetContext);
                _showSnackBar(context, "Numero WhatsApp copie");
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8EEF9),
                child: Icon(Icons.email_outlined, color: AppTheme.primaryColor),
              ),
              title: const Text("Email support"),
              subtitle: const Text("support@matontine.app"),
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: 'support@matontine.app'),
                );
                Navigator.pop(sheetContext);
                _showSnackBar(context, "Adresse email copiee");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        question,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            answer,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatLongMonth(DateTime date) {
    final raw = DateFormat('MMMM yyyy', 'fr_FR').format(date);
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final UserProfile profile;
  final TontineCycle? tontineCycle;
  final double availableBalance;

  const _ProfileHeroCard({
    required this.profile,
    required this.tontineCycle,
    required this.availableBalance,
  });

  @override
  Widget build(BuildContext context) {
    final cycleLabel = tontineCycle == null
        ? "Aucune tontine active"
        : "Cycle ${formatFCFA(tontineCycle!.targetAmount)} F";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.phoneNumber.isEmpty
                          ? "Numero non renseigne"
                          : profile.phoneNumber,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroInfo(label: "Tontine", value: cycleLabel),
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(
                  child: _HeroInfo(
                    label: "Disponible",
                    value: "${formatFCFA(availableBalance)} F",
                    alignEnd: true,
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

class _HeroInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _HeroInfo({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PreferenceSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }
}
