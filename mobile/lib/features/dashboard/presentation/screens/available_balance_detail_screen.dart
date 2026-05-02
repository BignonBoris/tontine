import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/available_balance_history_list.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_action_button.dart';

class AvailableBalanceDetailScreen extends StatelessWidget {
  const AvailableBalanceDetailScreen({super.key});

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
            label: "Chargement du solde disponible...",
          );
        }

        final activeGoals = state.goals
            .where((goal) => goal.status == GoalStatus.active)
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: AppBar(
            title: Text(
              "Solde disponible",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvailableHeroCard(
                  availableBalance: state.availableBalance,
                  goalsCount: activeGoals.length,
                ),
                const SizedBox(height: 20),
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TontineActionButton(
                            label: "Vers coffre",
                            icon: Icons.savings_outlined,
                            color: AppTheme.primaryColor,
                            onTap: () => _showFundGoalSheet(
                              context,
                              state.availableBalance,
                              activeGoals,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TontineActionButton(
                            label: "Vers tontine",
                            icon: Icons.lock_outline_rounded,
                            color: AppTheme.accentColor,
                            onTap: () =>
                                _showTransferToTontineSheet(context, state),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TontineActionButton(
                            label: "Historique",
                            icon: Icons.history_rounded,
                            color: const Color(0xFF00897B),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "L'historique du disponible est affiche plus bas.",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          TontineActionButton(
                            label: "Acheter",
                            icon: Icons.shopping_bag_outlined,
                            color: AppTheme.secondaryColor,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Le flux achat marketplace arrive dans l'etape suivante.",
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Historique du disponible",
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
                  child: AvailableBalanceHistoryList(
                    history: state.availableBalanceHistory,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFundGoalSheet(
    BuildContext context,
    double availableBalance,
    List<TontineGoal> goals,
  ) {
    final dashboardBloc = context.read<DashboardBloc>();

    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun coffre actif disponible.")),
      );
      return;
    }

    final controller = TextEditingController();
    TontineGoal? selectedGoal = goals.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    "Alimenter un coffre",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<TontineGoal>(
                    value: selectedGoal,
                    items: goals
                        .map(
                          (goal) => DropdownMenuItem(
                            value: goal,
                            child: Text(goal.title),
                          ),
                        )
                        .toList(),
                    onChanged: (goal) {
                      if (goal != null) {
                        setModalState(() {
                          selectedGoal = goal;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Choisir un coffre",
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Montant",
                      suffixText: "F CFA",
                      helperText:
                          "Disponible : ${formatFCFA(availableBalance)} F",
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(controller.text);
                        if (selectedGoal == null ||
                            amount == null ||
                            amount <= 0) {
                          _showSnackBar(context, "Montant invalide");
                          return;
                        }
                        if (amount > availableBalance) {
                          _showSnackBar(context, "Solde insuffisant");
                          return;
                        }

                        final remaining =
                            selectedGoal!.targetAmount -
                            selectedGoal!.currentAmount;
                        if (amount > remaining) {
                          _showSnackBar(
                            context,
                            "Le montant depasse l'objectif du coffre",
                          );
                          return;
                        }

                        dashboardBloc.add(
                          AddFundsToGoal(selectedGoal!.id, amount),
                        );
                        Navigator.pop(modalContext);
                      },
                      child: const Text("Confirmer"),
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

  void _showTransferToTontineSheet(
    BuildContext context,
    DashboardLoaded state,
  ) {
    final dashboardBloc = context.read<DashboardBloc>();
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
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
                "Retour vers la tontine",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.tontineCycle == null ||
                        state.tontineCycle!.status != TontineCycleStatus.active
                    ? "Aucune tontine active disponible pour recevoir ce montant."
                    : "Le montant doit etre un multiple de 500.",
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Montant",
                  suffixText: "F CFA",
                  helperText:
                      "Disponible : ${formatFCFA(state.availableBalance)} F",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (state.tontineCycle == null ||
                        state.tontineCycle!.status !=
                            TontineCycleStatus.active) {
                      _showSnackBar(
                        context,
                        "Aucune tontine active pour ce transfert",
                      );
                      return;
                    }

                    final amount = double.tryParse(controller.text);
                    if (amount == null || amount <= 0) {
                      _showSnackBar(context, "Montant invalide");
                      return;
                    }
                    if (amount % 500 != 0) {
                      _showSnackBar(
                        context,
                        "Le montant doit etre un multiple de 500",
                      );
                      return;
                    }
                    if (amount > state.availableBalance) {
                      _showSnackBar(context, "Solde insuffisant");
                      return;
                    }

                    final remaining =
                        state.tontineCycle!.targetAmount -
                        state.tontineCycle!.cumulativeAmount;
                    if (amount > remaining) {
                      _showSnackBar(
                        context,
                        "Le montant depasse l'objectif restant",
                      );
                      return;
                    }

                    dashboardBloc.add(TransferToTontine(amount));
                    Navigator.pop(modalContext);
                  },
                  child: const Text("Confirmer"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AvailableHeroCard extends StatelessWidget {
  final double availableBalance;
  final int goalsCount;

  const _AvailableHeroCard({
    required this.availableBalance,
    required this.goalsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F7B6C), Color(0xFF10A890)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Disponible maintenant",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${formatFCFA(availableBalance)} F",
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: "Coffres actifs",
                  value: goalsCount.toString(),
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: "Utilisable pour",
                  value: "Coffres / Achat",
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
