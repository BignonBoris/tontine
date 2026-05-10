import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_archive_entry.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/configure_tontine_stake_modal.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_action_button.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_history_list.dart';

class TontineDetailScreen extends StatelessWidget {
  final bool showBackButton;

  const TontineDetailScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardError) {
          return DashboardErrorView(
            title: state.title,
            message: state.message,
            requiresReauthentication: state.requiresReauthentication,
          );
        }

        if (state is! DashboardLoaded) {
          return const DashboardLoadingView(
            label: "Chargement de votre tontine...",
          );
        }

        final cycle = state.tontineCycle;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: AppBar(
            automaticallyImplyLeading: showBackButton,
            title: Text(
              "Tontine",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                onPressed: () =>
                    _showTontineArchives(context, state.tontineArchives),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TontineHeroCard(cycle: cycle),
                const SizedBox(height: 20),
                if (cycle != null)
                  _buildActionArea(context, cycle, state.availableBalance),
                const SizedBox(height: 24),
                Text(
                  "Historique tontine",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TontineHistoryList(history: state.tontineHistory),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionArea(
    BuildContext context,
    TontineCycle cycle,
    double availableBalance,
  ) {
    if (cycle.status == TontineCycleStatus.enAttenteValidationFin) {
      return _TontineInfoPanel(
        title: "Cycle atteint",
        description:
            "Votre objectif est complete. Confirmez le reversement vers le solde disponible.",
        child: Column(
          children: [
            _AmountLine(
              label: "Total cumule",
              value: "${formatFCFA(cycle.cumulativeAmount)} F",
            ),
            _AmountLine(
              label: "Commission plateforme",
              value: "${formatFCFA(cycle.commissionAmount)} F",
            ),
            _AmountLine(
              label: "Montant reverse",
              value: "${formatFCFA(cycle.netPayoutAmount)} F",
              isHighlighted: true,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final authorized = await LocalSecurityService.authorizeIfEnabled(
                    context,
                    title: 'Confirmer le reversement',
                    message:
                        "Entrez votre PIN pour confirmer le reversement vers le solde disponible.",
                  );
                  if (!context.mounted || !authorized) {
                    return;
                  }
                  context.read<DashboardBloc>().add(ConfirmTontineCyclePayout());
                },
                child: const Text("Confirmer le reversement"),
              ),
            ),
          ],
        ),
      );
    }

    if (cycle.status != TontineCycleStatus.active) {
      return _TontineInfoPanel(
        title: "Cycle non actif",
        description:
            "Ce cycle n'accepte plus de versement. Reconfigurez une nouvelle mise depuis le dashboard pour repartir a zero.",
        child: Column(
          children: [
            _AmountLine(
              label: "Dernier montant net de cycle",
              value: "${formatFCFA(cycle.netPayoutAmount)} F",
              isHighlighted: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showRestartTontineModal(context),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Recommencer une tontine"),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          TontineActionButton(
            label: "Verser",
            icon: Icons.add_circle_outline_rounded,
            color: AppTheme.secondaryColor,
            onTap: () => _showDepositSheet(context, cycle, availableBalance),
          ),
          const SizedBox(width: 12),
          TontineActionButton(
            label: "Arreter",
            icon: Icons.pause_circle_outline_rounded,
            color: AppTheme.errorColor,
            onTap: () => _showEarlyStopDialog(context, cycle),
          ),
        ],
      ),
    );
  }

  void _showDepositSheet(
    BuildContext context,
    TontineCycle cycle,
    double availableBalance,
  ) {
    final controller = TextEditingController();
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                "Transferer vers la tontine",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Le montant sera preleve de votre solde disponible. Il doit etre un multiple de 500 et ne peut pas depasser l'objectif du cycle.",
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineSheetError(message: errorMessage!),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) {
                  if (errorMessage != null) {
                    setSheetState(() => errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Montant a verser",
                  suffixText: "F CFA",
                  helperText:
                      "Disponible : ${formatFCFA(availableBalance)} F • Reste : ${formatFCFA((cycle.targetAmount - cycle.cumulativeAmount).toInt())} F",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(controller.text);
                    final remaining =
                        cycle.targetAmount - cycle.cumulativeAmount;

                    if (amount == null || amount <= 0) {
                      setSheetState(() => errorMessage = "Montant invalide");
                      return;
                    }
                    if (amount % 500 != 0) {
                      setSheetState(
                        () => errorMessage =
                            "Le montant doit etre un multiple de 500",
                      );
                      return;
                    }
                    if (amount > remaining) {
                      setSheetState(
                        () => errorMessage =
                            "Le montant depasse l'objectif restant",
                      );
                      return;
                    }
                    if (amount > availableBalance) {
                      setSheetState(
                        () => errorMessage =
                            "Solde disponible insuffisant",
                      );
                      return;
                    }

                    context.read<DashboardBloc>().add(
                      MakeTontineDeposit(amount),
                    );
                    Navigator.pop(modalContext);
                  },
                  child: const Text("Confirmer le transfert"),
                ),
              ),
              ],
            ),
          );
          },
        );
      },
    );
  }

  void _showEarlyStopDialog(BuildContext context, TontineCycle cycle) {
    final netAmount = (cycle.cumulativeAmount - cycle.commissionAmount).clamp(
      0.0,
      double.infinity,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Arreter la tontine ?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountLine(
                label: "Cumul actuel",
                value: "${formatFCFA(cycle.cumulativeAmount)} F",
              ),
              _AmountLine(
                label: "Commission",
                value: "${formatFCFA(cycle.commissionAmount)} F",
              ),
              _AmountLine(
                label: "Montant reverse",
                value: "${formatFCFA(netAmount)} F",
                isHighlighted: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                final authorized = await LocalSecurityService.authorizeIfEnabled(
                  context,
                  title: 'Arreter la tontine',
                  message:
                      "Entrez votre PIN pour confirmer l'arret anticipe de cette tontine.",
                );
                if (!context.mounted || !authorized) {
                  return;
                }
                context.read<DashboardBloc>().add(StopTontineEarly());
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text("Confirmer l'arret"),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRestartTontineModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return ConfigureTontineStakeModal(
          onSubmit: (amount) async {
            context.read<DashboardBloc>().add(ConfigureTontineStake(amount));
          },
        );
      },
    );
  }

  void _showTontineArchives(
    BuildContext context,
    List<TontineArchiveEntry> archives,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tontines precedentes",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              if (archives.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "Aucune tontine precedente.",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: archives.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final archive = archives[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.1,
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          "Objectif ${formatFCFA(archive.targetAmount)} F",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "Debut ${DateFormat('dd/MM/yyyy').format(archive.startDate)} - Fin ${DateFormat('dd/MM/yyyy').format(archive.endDate)}",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(modalContext);
                          _showArchiveSummary(context, archive);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showArchiveSummary(BuildContext context, TontineArchiveEntry archive) {
    final statusLabel = archive.status == TontineArchiveStatus.completed
        ? "Cycle termine"
        : "Arret anticipe";

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(statusLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountLine(
                label: "Date de debut",
                value: DateFormat('dd/MM/yyyy').format(archive.startDate),
              ),
              _AmountLine(
                label: "Date de fin",
                value: DateFormat('dd/MM/yyyy').format(archive.endDate),
              ),
              _AmountLine(
                label: "Objectif cycle",
                value: "${formatFCFA(archive.targetAmount)} F",
              ),
              _AmountLine(
                label: "Total cumule",
                value: "${formatFCFA(archive.cumulativeAmount)} F",
              ),
              _AmountLine(
                label: "Commission",
                value: "${formatFCFA(archive.commissionAmount)} F",
              ),
              _AmountLine(
                label: "Montant reverse",
                value: "${formatFCFA(archive.netPayoutAmount)} F",
                isHighlighted: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }
}

class _TontineHeroCard extends StatelessWidget {
  final TontineCycle? cycle;

  const _TontineHeroCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
    if (cycle == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aucune tontine active",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Reconfigurez une mise pour relancer un cycle depuis le dashboard.",
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF26359C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(cycle!.status),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${formatFCFA(cycle!.cumulativeAmount)} F",
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Objectif ${formatFCFA(cycle!.targetAmount)} F",
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: cycle!.progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.secondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: "Mise actuelle",
                  value: "${formatFCFA(cycle!.stakeAmount)} F",
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: "Progression",
                  value: "${(cycle!.progress * 100).toInt()}%",
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: "Net fin cycle",
                  value: "${formatFCFA(cycle!.netPayoutAmount)} F",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(TontineCycleStatus status) {
    switch (status) {
      case TontineCycleStatus.nonConfiguree:
        return "Non configuree";
      case TontineCycleStatus.active:
        return "Cycle actif";
      case TontineCycleStatus.enAttenteValidationFin:
        return "En attente de confirmation";
      case TontineCycleStatus.terminee:
        return "Cycle termine";
      case TontineCycleStatus.arretee:
        return "Cycle arretee";
    }
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TontineInfoPanel extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _TontineInfoPanel({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _AmountLine({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppTheme.secondaryColor : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineSheetError extends StatelessWidget {
  final String message;

  const _InlineSheetError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFFB71C1C),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}
