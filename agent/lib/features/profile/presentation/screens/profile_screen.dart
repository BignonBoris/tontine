import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/core/security/privacy_provider.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/home/data/services/agent_dashboard_service.dart';
import 'package:agent/features/home/domain/entities/agent_overview.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _dashboardService = AgentDashboardService();
  late Future<AgentOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _dashboardService.fetchOverview();
  }

  Future<void> _reload() async {
    setState(() {
      _overviewFuture = _dashboardService.fetchOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mon Compte'),
        actions: const [
          PrivacyToggleButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildAgentHeader(),
            const SizedBox(height: 24),
            _buildCommissionsSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
            const SizedBox(height: 24),
            _buildSystemSection(),
            const SizedBox(height: 32),
            const AgentLogoutAction(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AgentAppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 40,
            color: AgentAppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Agent VizioBox',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AgentAppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AgentAppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Code: A-0001', // TODO: Get from auth service
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AgentAppTheme.secondaryVariantColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionsSection() {
    return FutureBuilder<AgentOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AgentLoadingView(message: 'Chargement des commissions...');
        }
        
        final isPrivate = PrivacyProvider.of(context).isPrivate;
        final overview = snapshot.data;
        final commissionBalance = overview?.commissionBalance ?? 0.0;
        final commissionPayable = overview?.commissionPayableBalance ?? 0.0;

        return SoftSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AgentAppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.military_tech_rounded,
                      color: AgentAppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mes Commissions',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AgentAppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Solde total',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AgentAppTheme.textSecondaryColor,
                    ),
                  ),
                  Text(
                    isPrivate ? '*** ***F CFA' : '${commissionBalance.toStringAsFixed(0)}F CFA',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AgentAppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Retirable',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AgentAppTheme.textSecondaryColor,
                    ),
                  ),
                  Text(
                    isPrivate ? '*** ***F CFA' : '${commissionPayable.toStringAsFixed(0)}F CFA',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AgentAppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecuritySection() {
    return SoftSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sécurité',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AgentAppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password_rounded),
            title: const Text('Modifier le code PIN'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {}, // TODO: Implement PIN change
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fingerprint_rounded),
            title: const Text('Biométrie'),
            trailing: Switch(
              value: false, // TODO: Implement Biometric switch
              onChanged: (val) {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSection() {
    return SoftSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Système',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AgentAppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Synchronisation manuelle'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {}, // TODO: Implement force sync
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Support technique'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
