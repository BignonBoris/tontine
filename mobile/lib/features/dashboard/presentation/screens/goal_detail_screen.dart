import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_action_button.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

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
          return const DashboardLoadingView(label: "Chargement du coffre...");
        }

        final goal = state.goals.firstWhere(
          (g) => g.id == widget.goalId,
          orElse: () => state.goals.first,
        );

        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFF8F9FE),
              appBar: AppBar(
                title: Text(
                  goal.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.archive_outlined,
                      color: AppTheme.errorColor,
                    ),
                    onPressed: () => _confirmClose(context, goal),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${formatFCFA(goal.currentAmount)} F",
                            style: GoogleFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: goal.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Objectif ${formatFCFA(goal.targetAmount)} F",
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: goal.progress,
                              minHeight: 12,
                              backgroundColor: goal.color.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                goal.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _HeroMetric(
                                  label: "Progression",
                                  value: "${(goal.progress * 100).toInt()}%",
                                ),
                              ),
                              Expanded(
                                child: _HeroMetric(
                                  label: "Reste",
                                  value:
                                      "${formatFCFA((goal.targetAmount - goal.currentAmount).toInt())} F",
                                ),
                              ),
                              Expanded(
                                child: _HeroMetric(
                                  label: "Echeance",
                                  value: "${goal.remainingDays} j",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
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
                              label: "Deposer",
                              icon: Icons.add_circle_outline_rounded,
                              color: AppTheme.secondaryColor,
                              onTap: () =>
                                  _showDepositSheet(context, state, goal),
                            ),
                            const SizedBox(width: 12),
                            TontineActionButton(
                              label: "Cloturer",
                              icon: Icons.archive_outlined,
                              color: AppTheme.errorColor,
                              onTap: () => _confirmClose(context, goal),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
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
                            "Historique",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (goal.transactions.isEmpty)
                            _buildEmptyHistory()
                          else
                            _buildTransactionList(goal),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.orange,
                  Colors.pink,
                ],
                numberOfParticles: 30,
                gravity: 0.1,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDepositSheet(
    BuildContext context,
    DashboardLoaded state,
    TontineGoal goal,
  ) {
    final amountController = TextEditingController();
    final remaining = goal.targetAmount - goal.currentAmount;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Effectuer un depot",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Le montant viendra du solde disponible et ne peut pas depasser l'objectif restant.",
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) {
                    if (errorMessage != null) {
                      setSheetState(() => errorMessage = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: "Montant a deposer",
                    suffixText: "F CFA",
                    helperText:
                        "Reste a completer : ${formatFCFA(remaining.toInt())} F",
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _InlineSheetError(message: errorMessage!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountController.text);

                      if (amount == null || amount <= 0) {
                        setSheetState(
                          () => errorMessage = "Montant invalide",
                        );
                        return;
                      }
                      if (amount > state.availableBalance) {
                        setSheetState(
                          () => errorMessage =
                              "Solde insuffisant (${state.availableBalance.toInt()} F)",
                        );
                        return;
                      }
                      if (amount > remaining) {
                        setSheetState(
                          () => errorMessage =
                              "Le montant depasse l'objectif",
                        );
                        return;
                      }

                      context.read<DashboardBloc>().add(
                        AddFundsToGoal(goal.id, amount),
                      );
                      Navigator.pop(sheetContext);
                      _confettiController.play();
                      _showSnackBar(
                        context,
                        "Depot de ${amount.toInt()} F effectue",
                      );
                    },
                    child: const Text("Confirmer le depot"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Aucune operation pour le moment",
            style: GoogleFonts.inter(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(TontineGoal goal) {
    return ListView.builder(
      itemCount: goal.transactions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final tx = goal.transactions[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: tx.isDeposit
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            child: Icon(
              tx.isDeposit ? Icons.add : Icons.remove,
              color: tx.isDeposit ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Text(
            tx.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            "${tx.isDeposit ? '+' : '-'} ${formatFCFA(tx.amount.toInt())} F",
            style: TextStyle(
              color: tx.isDeposit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _confirmClose(BuildContext context, TontineGoal goal) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cloturer le coffre ?"),
        content: Text(
          "Le solde de ${goal.currentAmount.toInt()} F sera reverse sur votre compte disponible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              final authorized = await LocalSecurityService.authorizeIfEnabled(
                context,
                title: 'Cloturer le coffre',
                message:
                    "Entrez votre PIN pour confirmer la cloture de ce coffre.",
              );
              if (!context.mounted || !authorized) {
                return;
              }
              context.read<DashboardBloc>().add(CloseGoal(goal.id));
              Navigator.pop(dialogContext);
            },
            child: const Text("Confirmer"),
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
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}
