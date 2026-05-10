import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/available_balance_history_entry.dart';
import 'package:mobile/features/dashboard/domain/entities/withdrawal_summary.dart';
import 'package:mobile/features/dashboard/domain/entities/withdrawal_request_result.dart';
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
                            label: "Retirer",
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF00897B),
                            onTap: () =>
                                _showWithdrawalSheet(context, state),
                          ),
                          const SizedBox(width: 12),
                          TontineActionButton(
                            label: "Historique",
                            icon: Icons.history_rounded,
                            color: AppTheme.secondaryColor,
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
                    onTap: (entry) => _showHistoryDetailDialog(
                      context,
                      entry,
                      state.withdrawals,
                    ),
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
    String? errorMessage;

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
                          errorMessage = null;
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
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setModalState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Montant",
                      suffixText: "F CFA",
                      helperText:
                          "Disponible : ${formatFCFA(availableBalance)} F",
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _InlineSheetError(message: errorMessage!),
                  ],
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
                          setModalState(
                            () => errorMessage = "Montant invalide",
                          );
                          return;
                        }
                        if (amount > availableBalance) {
                          setModalState(
                            () => errorMessage = "Solde insuffisant",
                          );
                          return;
                        }

                        final remaining =
                            selectedGoal!.targetAmount -
                            selectedGoal!.currentAmount;
                        if (amount > remaining) {
                          setModalState(
                            () => errorMessage =
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
    String? errorMessage;

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
                    "Retour vers la tontine",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.tontineCycle == null ||
                            state.tontineCycle!.status !=
                                TontineCycleStatus.active
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
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setModalState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Montant",
                      suffixText: "F CFA",
                      helperText:
                          "Disponible : ${formatFCFA(state.availableBalance)} F",
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _InlineSheetError(message: errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (state.tontineCycle == null ||
                            state.tontineCycle!.status !=
                                TontineCycleStatus.active) {
                          setModalState(
                            () => errorMessage =
                                "Aucune tontine active pour ce transfert",
                          );
                          return;
                        }

                        final amount = double.tryParse(controller.text);
                        if (amount == null || amount <= 0) {
                          setModalState(
                            () => errorMessage = "Montant invalide",
                          );
                          return;
                        }
                        if (amount % 500 != 0) {
                          setModalState(
                            () => errorMessage =
                                "Le montant doit etre un multiple de 500",
                          );
                          return;
                        }
                        if (amount > state.availableBalance) {
                          setModalState(
                            () => errorMessage = "Solde insuffisant",
                          );
                          return;
                        }

                        final remaining =
                            state.tontineCycle!.targetAmount -
                            state.tontineCycle!.cumulativeAmount;
                        if (amount > remaining) {
                          setModalState(
                            () => errorMessage =
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
      },
    );
  }

  Future<void> _showWithdrawalSheet(
    BuildContext context,
    DashboardLoaded state,
  ) async {
    final dashboardBloc = context.read<DashboardBloc>();
    final service = RemoteDashboardService();
    final controller = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    await showModalBottomSheet<void>(
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
                    "Demander un retrait",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Le montant sera reserve, puis un agent vous paiera apres verification de la reference et du code de confirmation.",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setModalState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Montant",
                      suffixText: "F CFA",
                      helperText:
                          "Disponible : ${formatFCFA(state.availableBalance)} F",
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _InlineSheetError(message: errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amount = double.tryParse(controller.text);
                              if (amount == null || amount <= 0) {
                                setModalState(
                                  () => errorMessage = "Montant invalide",
                                );
                                return;
                              }
                              if (amount % 500 != 0) {
                                setModalState(
                                  () => errorMessage =
                                      "Le montant doit etre un multiple de 500",
                                );
                                return;
                              }
                              if (amount > state.availableBalance) {
                                setModalState(
                                  () => errorMessage =
                                      "Solde disponible insuffisant",
                                );
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });
                              try {
                                final result = await service.requestWithdrawal(
                                  amount,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.pop(modalContext);
                                dashboardBloc.add(LoadDashboardData());
                                await _showWithdrawalSummaryDialog(
                                  context,
                                  result,
                                );
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }
                                final message = error is Exception
                                    ? error.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        )
                                    : "Le retrait n'a pas pu etre initie.";
                                setModalState(() {
                                  errorMessage = message;
                                  isSubmitting = false;
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Generer ma reference"),
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

  Future<void> _showWithdrawalSummaryDialog(
    BuildContext context,
    WithdrawalRequestResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Retrait initialise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(
                label: 'Montant',
                value: '${formatFCFA(result.amount)} F',
                isHighlighted: true,
              ),
              _InfoLine(label: 'Reference', value: result.reference),
              _InfoLine(
                label: 'Code client',
                value: result.confirmationCode,
                isHighlighted: true,
              ),
              _InfoLine(
                label: 'Valable jusqu au',
                value: _formatDate(result.confirmationCodeExpiresAt),
              ),
              const SizedBox(height: 12),
              Text(
                "Communiquez la reference a l'agent, puis gardez ce code pour confirmer le paiement.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'Reference: ${result.reference} | Code: ${result.confirmationCode}',
                  ),
                );
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Reference et code copies.'),
                      ),
                    );
                }
              },
              child: const Text('Copier'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHistoryDetailDialog(
    BuildContext context,
    AvailableBalanceHistoryEntry entry,
    List<WithdrawalSummary> withdrawals,
  ) async {
    final linkedWithdrawal = _findLinkedWithdrawal(entry, withdrawals);
    final dashboardBloc = context.read<DashboardBloc>();
    final service = RemoteDashboardService();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Detail operation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(label: 'Libelle', value: entry.label),
                  _InfoLine(
                    label: 'Montant',
                    value:
                        '${entry.isCredit ? '+' : '-'} ${formatFCFA(entry.amount)} F',
                    isHighlighted: true,
                  ),
                  _InfoLine(label: 'Date', value: _formatDate(entry.date)),
                  _InfoLine(
                    label: 'Sens',
                    value: entry.isCredit ? 'Credit' : 'Debit',
                  ),
                  if (linkedWithdrawal != null) ...[
                    _InfoLine(
                      label: 'Reference',
                      value: linkedWithdrawal.reference,
                    ),
                    _InfoLine(
                      label: 'Statut retrait',
                      value: _withdrawalStatusLabel(linkedWithdrawal.status),
                      isHighlighted: linkedWithdrawal.status == 'paid',
                    ),
                    if (linkedWithdrawal.confirmationCodeExpiresAt != null)
                      _InfoLine(
                        label: 'Code',
                        value: linkedWithdrawal.isConfirmationCodeExpired
                            ? 'Expire'
                            : 'Deja genere',
                      ),
                    if (linkedWithdrawal.confirmationCodeExpiresAt != null)
                      _InfoLine(
                        label: 'Valable jusqu au',
                        value: _formatDate(
                          linkedWithdrawal.confirmationCodeExpiresAt!,
                        ),
                      ),
                    if (!linkedWithdrawal.isConfirmationCodeExpired &&
                        linkedWithdrawal.status == 'requested')
                      Text(
                        "Le code actif a deja ete genere. Si vous ne l'avez plus, attendez son expiration puis generez-en un nouveau.",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    if (linkedWithdrawal.paidAt != null)
                      _InfoLine(
                        label: 'Paye le',
                        value: _formatDate(linkedWithdrawal.paidAt!),
                      ),
                    if (linkedWithdrawal.cancelledAt != null)
                      _InfoLine(
                        label: 'Annule le',
                        value: _formatDate(linkedWithdrawal.cancelledAt!),
                      ),
                    if ((linkedWithdrawal.cancellationReason ?? '').isNotEmpty)
                      _InfoLine(
                        label: 'Motif',
                        value: linkedWithdrawal.cancellationReason!,
                      ),
                  ],
                ],
              ),
              actions: [
                if (linkedWithdrawal != null &&
                    linkedWithdrawal.status == 'requested' &&
                    linkedWithdrawal.isConfirmationCodeExpired)
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            try {
                              final result = await service
                                  .regenerateWithdrawalCode(linkedWithdrawal.id);
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.pop(dialogContext);
                              dashboardBloc.add(LoadDashboardData());
                              await _showWithdrawalSummaryDialog(
                                context,
                                result,
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              final message = error is Exception
                                  ? error.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      )
                                  : "Le nouveau code n'a pas pu etre genere.";
                              _showSnackBar(context, message);
                              setDialogState(() => isSubmitting = false);
                            }
                          },
                    child: const Text('Generer un nouveau code'),
                  ),
                if (linkedWithdrawal != null &&
                    linkedWithdrawal.status == 'requested')
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            try {
                              await service.cancelWithdrawal(linkedWithdrawal.id);
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.pop(dialogContext);
                              dashboardBloc.add(LoadDashboardData());
                              _showSnackBar(context, 'Retrait annule.');
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              final message = error is Exception
                                  ? error.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      )
                                  : "Le retrait n'a pas pu etre annule.";
                              _showSnackBar(context, message);
                              setDialogState(() => isSubmitting = false);
                            }
                          },
                    child: const Text('Annuler le retrait'),
                  ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  WithdrawalSummary? _findLinkedWithdrawal(
    AvailableBalanceHistoryEntry entry,
    List<WithdrawalSummary> withdrawals,
  ) {
    final match = RegExp(r'WDR-[A-Z0-9-]+').firstMatch(entry.label);
    if (match == null) {
      return null;
    }

    final reference = match.group(0);
    if (reference == null) {
      return null;
    }

    for (final withdrawal in withdrawals) {
      if (withdrawal.reference == reference) {
        return withdrawal;
      }
    }

    return null;
  }

  String _withdrawalStatusLabel(String status) {
    switch (status) {
      case 'requested':
        return 'En attente de paiement';
      case 'paid':
        return 'Paye';
      case 'cancelled':
        return 'Annule';
      default:
        return status;
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _InfoLine({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? AppTheme.secondaryColor : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
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
