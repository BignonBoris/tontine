import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSliverHeader extends StatefulWidget {
  final double availableBalance;
  final double tontineBalance;
  final VoidCallback? onAvailableTap;
  final VoidCallback? onTontineTap;
  final UserProfile? profile;
  final VoidCallback? onProfileTap;
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationsTap;
  final GlobalKey? profileKey;
  final GlobalKey? balancesKey;

  const DashboardSliverHeader({
    super.key,
    required this.availableBalance,
    required this.tontineBalance,
    this.onAvailableTap,
    this.onTontineTap,
    this.profile,
    this.onProfileTap,
    this.unreadNotificationsCount = 0,
    this.onNotificationsTap,
    this.profileKey,
    this.balancesKey,
  });

  @override
  State<DashboardSliverHeader> createState() => _DashboardSliverHeaderState();
}

class _DashboardSliverHeaderState extends State<DashboardSliverHeader> {
  static const String _visibilityPrefKey = 'app.balance_visibility';
  bool _isBalanceVisible = false;

  @override
  void initState() {
    super.initState();
    _loadVisibilityPreference();
  }

  Future<void> _loadVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_visibilityPrefKey);
    if (mounted) {
      setState(() {
        _isBalanceVisible = saved ?? false;
      });
    }
  }

  Future<void> _toggleVisibility() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibilityPrefKey, _isBalanceVisible);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final minExtent = kToolbarHeight + topPadding;
    final maxExtent = topPadding + 242.0;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _DashboardSliverHeaderDelegate(
        availableBalance: widget.availableBalance,
        tontineBalance: widget.tontineBalance,
        profile: widget.profile,
        onProfileTap: widget.onProfileTap,
        unreadNotificationsCount: widget.unreadNotificationsCount,
        onNotificationsTap: widget.onNotificationsTap,
        onAvailableTap: widget.onAvailableTap,
        onTontineTap: widget.onTontineTap,
        isBalanceVisible: _isBalanceVisible,
        onToggleVisibility: _toggleVisibility,
        topPadding: topPadding,
        minExtentValue: minExtent,
        maxExtentValue: maxExtent,
        profileKey: widget.profileKey,
        balancesKey: widget.balancesKey,
      ),
    );
  }
}

class _DashboardSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double availableBalance;
  final double tontineBalance;
  final UserProfile? profile;
  final VoidCallback? onProfileTap;
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvailableTap;
  final VoidCallback? onTontineTap;
  final bool isBalanceVisible;
  final VoidCallback onToggleVisibility;
  final double topPadding;
  final double minExtentValue;
  final double maxExtentValue;
  final GlobalKey? profileKey;
  final GlobalKey? balancesKey;

  _DashboardSliverHeaderDelegate({
    required this.availableBalance,
    required this.tontineBalance,
    this.profile,
    this.onProfileTap,
    this.unreadNotificationsCount = 0,
    this.onNotificationsTap,
    this.onAvailableTap,
    this.onTontineTap,
    required this.isBalanceVisible,
    required this.onToggleVisibility,
    required this.topPadding,
    required this.minExtentValue,
    required this.maxExtentValue,
    this.profileKey,
    this.balancesKey,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'VB';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    return (hour >= 5 && hour < 18) ? 'Bonjour' : 'Bonsoir';
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final totalBalance = availableBalance + tontineBalance;
    final displayName = profile?.displayName ?? 'Membre';
    final firstName = displayName.split(' ').first;
    final initials = _getInitials(displayName);
    final greeting = _getGreeting();

    // Facteur de rétractation (0.0 = complètement déplié, 1.0 = compact / épinglé)
    final progress =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    // Opacité de la zone de solde qui s'estompe rapidement au scroll
    final balanceOpacity = (1.0 - (progress * 2.0)).clamp(0.0, 1.0);
    final isPinned = progress >= 0.75;
    final bottomRadius = (26.0 * (1.0 - progress)).clamp(0.0, 26.0);

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: isPinned ? 0.35 : 0.18),
            blurRadius: isPinned ? 14 : 20,
            offset: Offset(0, isPinned ? 3 : 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Cercles d'arrière-plan en filigrane (Charte VizioBox)
          Positioned(
            top: -25,
            right: -15,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -35,
            left: -25,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Rangée 1 : Salutation & Avatar + Cloche de notification (Toujours Pinned en haut)
          Positioned(
            top: topPadding + 8,
            left: 20,
            right: 20,
            child: KeyedSubtree(
              key: profileKey,
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.80),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            greeting,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                firstName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Emoji décoratif : masqué aux lecteurs d'écran
                              // (sinon TalkBack annonce "visage souriant main
                              // qui salue" à chaque lecture du header).
                              const ExcludeSemantics(
                                child: Text(
                                  '👋',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bouton Cloche de Notifications
                // Cible tactile 44x44 dp (Apple HIG / WCAG 2.5.8) + libellé
                // accessible via Tooltip (annoncé par TalkBack/VoiceOver).
                Tooltip(
                  message: 'Notifications',
                  child: InkWell(
                    onTap: onNotificationsTap,
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (unreadNotificationsCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  // WCAG 1.4.3 : blanc sur D32F2F = 4.98:1
                                  // (E53935 = 4.23:1 échouait à 10px).
                                  color: AppTheme.errorColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  unreadNotificationsCount > 9
                                      ? '9+'
                                      : '$unreadNotificationsCount',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

          // Rangée 2 : Section Solde Aérée & Harmonieuse (Espacement naturel)
          if (balanceOpacity > 0.01)
            Positioned(
              top: topPadding + 68,
              left: 20,
              right: 20,
              child: Opacity(
                opacity: balanceOpacity,
                child: KeyedSubtree(
                  key: balancesKey,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre Solde Total + Bouton Œil
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 12,
                                color: AppTheme.accentColor.withValues(alpha: 0.90),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SOLDE TOTAL ESTIMÉ',
                                style: GoogleFonts.inter(
                                  // >= 11sp : minimum Material pour les labels.
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bouton Œil Masquer/Afficher
                        // Cible tactile >= 40 dp + libellé accessible
                        // (WCAG 2.5.8 / 4.1.2).
                        Tooltip(
                          message: isBalanceVisible
                              ? 'Masquer le solde'
                              : 'Afficher le solde',
                          child: InkWell(
                            onTap: onToggleVisibility,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isBalanceVisible
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 15,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isBalanceVisible ? 'Masquer' : 'Afficher',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Montant Principal
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      // Accessibilité : le lecteur d'écran annonce un libellé
                      // parlant au lieu des points de masquage "••••••••".
                      child: Semantics(
                        label: isBalanceVisible
                            ? 'Solde total : ${formatFCFA(totalBalance.toInt())} francs CFA'
                            : 'Solde total masqué',
                        excludeSemantics: true,
                        child: Text(
                          isBalanceVisible
                              ? '${formatFCFA(totalBalance.toInt())} FCFA'
                              : '•••••••• FCFA',
                          key: ValueKey<bool>(isBalanceVisible),
                          style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: isBalanceVisible ? 0.3 : 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Séparateur fin
                    Divider(
                      color: Colors.white.withValues(alpha: 0.12),
                      height: 1,
                    ),
                    const SizedBox(height: 8),

                    // Deux sous-soldes (Disponible vs En tontine)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubBalance(
                            label: 'Disponible',
                            subLabel: 'Retirable',
                            amount: availableBalance,
                            color: AppTheme.secondaryColor,
                            icon: Icons.lock_open_rounded,
                            onTap: onAvailableTap,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSubBalance(
                            label: 'En tontine',
                            subLabel: 'Tour en cours',
                            amount: tontineBalance,
                            color: AppTheme.accentColor,
                            icon: Icons.lock_rounded,
                            onTap: onTontineTap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubBalance({
    required String label,
    required String subLabel,
    required double amount,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    // Accessibilité : le lecteur d'écran annonce un bloc unique et parlant
    // (label + montant + statut), y compris lorsque le solde est masqué.
    final accessibleLabel = isBalanceVisible
        ? '$label : ${formatFCFA(amount.toInt())} francs CFA, $subLabel'
        : '$label : montant masqué, $subLabel';

    final content = Semantics(
      label: accessibleLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              // ISO 4217 : unité explicite, même en mode masqué.
              isBalanceVisible
                  ? '${formatFCFA(amount.toInt())} FCFA'
                  : '•••••• FCFA',
              key: ValueKey<String>('$isBalanceVisible-$amount'),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            subLabel,
            // Taille >= 11sp (l'ancien 9.5sp était sous le minimum Material)
            // et alpha 0.72 (≈ 7.6:1 sur bleu nuit, WCAG 1.4.3 conforme).
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }

  @override
  bool shouldRebuild(covariant _DashboardSliverHeaderDelegate oldDelegate) {
    return availableBalance != oldDelegate.availableBalance ||
        tontineBalance != oldDelegate.tontineBalance ||
        profile != oldDelegate.profile ||
        unreadNotificationsCount != oldDelegate.unreadNotificationsCount ||
        isBalanceVisible != oldDelegate.isBalanceVisible ||
        topPadding != oldDelegate.topPadding;
  }
}
