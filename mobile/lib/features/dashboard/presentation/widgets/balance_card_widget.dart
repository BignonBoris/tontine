import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BalanceCardWidget extends StatefulWidget {
  final double availableBalance;
  final double tontineBalance;
  final VoidCallback? onAvailableTap;
  final VoidCallback? onTontineTap;
  final UserProfile? profile;
  final VoidCallback? onProfileTap;
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationsTap;
  final bool isImmersiveHeader;

  const BalanceCardWidget({
    super.key,
    required this.availableBalance,
    required this.tontineBalance,
    this.onAvailableTap,
    this.onTontineTap,
    this.profile,
    this.onProfileTap,
    this.unreadNotificationsCount = 0,
    this.onNotificationsTap,
    this.isImmersiveHeader = true,
  });

  @override
  State<BalanceCardWidget> createState() => _BalanceCardWidgetState();
}

class _BalanceCardWidgetState extends State<BalanceCardWidget> {
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
  Widget build(BuildContext context) {
    final totalBalance = widget.availableBalance + widget.tontineBalance;
    final topPadding = widget.isImmersiveHeader
        ? (MediaQuery.of(context).padding.top + 14)
        : 20.0;
    final displayName = widget.profile?.displayName ?? 'Membre';
    final firstName = displayName.split(' ').first;
    final initials = _getInitials(displayName);
    final greeting = _getGreeting();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: widget.isImmersiveHeader
            ? const BorderRadius.vertical(bottom: Radius.circular(32))
            : BorderRadius.circular(26),
        border: widget.isImmersiveHeader
            ? null
            : Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.28),
                width: 1.2,
              ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.accentDarkColor.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Cercles d'arrière-plan en filigrane (Charte VizioBox)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rangée 1 : Salutation & Avatar + Cloche de notification (Option 2)
                if (widget.isImmersiveHeader) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: widget.onProfileTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.accentColor
                                      .withValues(alpha: 0.80),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  greeting,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      firstName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '👋',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Bouton de notifications stylisé
                      InkWell(
                        onTap: widget.onNotificationsTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
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
                                  size: 21,
                                ),
                              ),
                            ),
                            if (widget.unreadNotificationsCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
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
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.primaryColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    widget.unreadNotificationsCount > 9
                                        ? '9+'
                                        : '${widget.unreadNotificationsCount}',
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],

                // Rangée 2 : Titre Solde Total + Bouton Œil (Confidentialité)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 12,
                                color: AppTheme.accentColor
                                    .withValues(alpha: 0.90),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'SOLDE TOTAL ESTIMÉ',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Bouton Œil (Afficher / Masquer les montants)
                    InkWell(
                      onTap: _toggleVisibility,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
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
                              _isBalanceVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.90),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isBalanceVisible ? 'Masquer' : 'Afficher',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Montant principal en gros (Typographie Poppins)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _isBalanceVisible
                        ? '${formatFCFA(totalBalance.toInt())} FCFA'
                        : '•••••••• FCFA',
                    key: ValueKey<bool>(_isBalanceVisible),
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: _isBalanceVisible ? 0.3 : 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Séparateur fin
                Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 1,
                ),
                const SizedBox(height: 14),

                // Deux sous-soldes : Disponible vs En Tontine
                Row(
                  children: [
                    Expanded(
                      child: _buildSubBalance(
                        label: 'Disponible',
                        subLabel: 'Retirable',
                        amount: widget.availableBalance,
                        color: AppTheme.secondaryColor,
                        icon: Icons.lock_open_rounded,
                        onTap: widget.onAvailableTap,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 38,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildSubBalance(
                        label: 'En tontine',
                        subLabel: 'Tour en cours',
                        amount: widget.tontineBalance,
                        color: AppTheme.accentColor,
                        icon: Icons.lock_rounded,
                        onTap: widget.onTontineTap,
                      ),
                    ),
                  ],
                ),
              ],
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 13.5,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _isBalanceVisible
                ? '${formatFCFA(amount.toInt())} F'
                : '•••••• F',
            key: ValueKey<String>('$_isBalanceVisible-$amount'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subLabel,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}
