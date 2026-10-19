import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
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
import 'package:mobile/features/dashboard/presentation/widgets/finance_hero_header.dart';
import 'package:mobile/features/dashboard/presentation/widgets/withdrawal_qr_modal.dart';

/// Statuts d'un retrait dont le montant est encore réservé sur le disponible.
const _pendingWithdrawalStatuses = {'requested', 'approved'};

/// Nombre de lignes d'historique affichées avant « Voir tout ».
const _historyPreviewCount = 8;

enum _HistoryFilter { all, credits, debits }

class AvailableBalanceDetailScreen extends StatefulWidget {
  const AvailableBalanceDetailScreen({super.key});

  @override
  State<AvailableBalanceDetailScreen> createState() =>
      _AvailableBalanceDetailScreenState();
}

class _AvailableBalanceDetailScreenState
    extends State<AvailableBalanceDetailScreen> {
  _HistoryFilter _historyFilter = _HistoryFilter.all;
  bool _showAllHistory = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardOffline) {
          return DashboardOfflineView(
            title: state.title,
            message: state.message,
            inline: true,
          );
        }

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
        final pendingWithdrawals = state.withdrawals
            .where((w) => _pendingWithdrawalStatuses.contains(w.status))
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        final reservedAmount = pendingWithdrawals.fold<double>(
          0,
          (sum, w) => sum + w.amount,
        );

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Column(
            children: [
              FinanceHeroHeader(
                title: "Solde disponible",
                titleFontSize: 18,
                showBackButton: true,
                bottom: _BalanceHeroSummary(
                  availableBalance: state.availableBalance,
                  reservedAmount: reservedAmount,
                  goalsCount: activeGoals.length,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickActionsCard(
                        onFundGoal: () => _showFundGoalSheet(
                          context,
                          state.availableBalance,
                          activeGoals,
                        ),
                        onTransferToTontine: () =>
                            _showTransferToTontineSheet(context, state),
                        onWithdraw: () => _showWithdrawalSheet(context, state),
                      ),
                      if (pendingWithdrawals.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _PendingWithdrawalCard(
                          withdrawal: pendingWithdrawals.first,
                          otherCount: pendingWithdrawals.length - 1,
                          onShowQr: () => WithdrawalQrModal.show(
                            context,
                            _resultFromSummary(pendingWithdrawals.first),
                          ),
                          onRegenerateCode: () => _regenerateWithdrawalCode(
                            context,
                            pendingWithdrawals.first,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildHistoryCard(context, state),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, DashboardLoaded state) {
    final filtered = state.availableBalanceHistory.where((entry) {
      switch (_historyFilter) {
        case _HistoryFilter.all:
          return true;
        case _HistoryFilter.credits:
          return entry.isCredit;
        case _HistoryFilter.debits:
          return !entry.isCredit;
      }
    }).toList();
    final visible = _showAllHistory
        ? filtered
        : filtered.take(_historyPreviewCount).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Historique",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: "Tout",
                selected: _historyFilter == _HistoryFilter.all,
                onTap: () => _setHistoryFilter(_HistoryFilter.all),
              ),
              _FilterChip(
                label: "Entrées",
                selected: _historyFilter == _HistoryFilter.credits,
                onTap: () => _setHistoryFilter(_HistoryFilter.credits),
              ),
              _FilterChip(
                label: "Sorties",
                selected: _historyFilter == _HistoryFilter.debits,
                onTap: () => _setHistoryFilter(_HistoryFilter.debits),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AvailableBalanceHistoryList(
            history: visible,
            onTap: (entry) => _showHistoryDetailSheet(
              context,
              entry,
              state.withdrawals,
            ),
          ),
          if (filtered.length > _historyPreviewCount)
            Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _showAllHistory = !_showAllHistory),
                child: Text(
                  _showAllHistory
                      ? "Réduire"
                      : "Voir tout (${filtered.length})",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentDarkColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setHistoryFilter(_HistoryFilter filter) {
    setState(() {
      _historyFilter = filter;
      _showAllHistory = false;
    });
  }

  // ── Alimenter un coffre ─────────────────────────────────────────────────────

  void _showFundGoalSheet(
    BuildContext context,
    double availableBalance,
    List<TontineGoal> goals,
  ) {
    final dashboardBloc = context.read<DashboardBloc>();

    if (goals.isEmpty) {
      _showSnackBar(context, "Aucun coffre actif disponible.");
      return;
    }

    final controller = TextEditingController();
    TontineGoal selectedGoal = goals.first;
    String? errorMessage;

    _showActionSheet(
      context,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final remaining =
              selectedGoal.targetAmount - selectedGoal.currentAmount;
          final maxAmount =
              remaining < availableBalance ? remaining : availableBalance;

          return _ActionSheetBody(
            title: "Alimenter un coffre",
            subtitle: "Disponible : ${formatFCFA(availableBalance)} F CFA",
            children: [
              const _SheetLabel("Coffre"),
              ...goals.map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ChoiceTile(
                    icon: goal.icon,
                    iconColor: goal.color,
                    title: goal.title,
                    subtitle:
                        "Reste ${formatFCFA(goal.targetAmount - goal.currentAmount)} F à épargner",
                    selected: goal.id == selectedGoal.id,
                    onTap: () => setModalState(() {
                      selectedGoal = goal;
                      errorMessage = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _SheetLabel("Montant"),
              _AmountInput(
                controller: controller,
                onChanged: () => setModalState(() => errorMessage = null),
              ),
              const SizedBox(height: 10),
              _QuickAmountChips(
                controller: controller,
                maxAmount: maxAmount,
                onSelected: () => setModalState(() => errorMessage = null),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineSheetError(message: errorMessage!),
              ],
              const SizedBox(height: 14),
              const _SheetHint("Confirmation par votre code PIN."),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: "Alimenter le coffre",
                onPressed: () async {
                  final amount = double.tryParse(controller.text);
                  if (amount == null || amount <= 0) {
                    setModalState(() => errorMessage = "Montant invalide.");
                    return;
                  }
                  if (amount > availableBalance) {
                    setModalState(
                      () => errorMessage = "Solde disponible insuffisant.",
                    );
                    return;
                  }
                  if (amount > remaining) {
                    setModalState(
                      () => errorMessage =
                          "Le montant dépasse l'objectif restant du coffre.",
                    );
                    return;
                  }

                  final authorized =
                      await LocalSecurityService.authorizeIfEnabled(
                        context,
                        title: 'Alimenter un coffre',
                        message:
                            "Entrez votre PIN pour confirmer le dépôt vers ${selectedGoal.title}.",
                      );
                  if (!context.mounted || !authorized) {
                    return;
                  }

                  dashboardBloc.add(AddFundsToGoal(selectedGoal.id, amount));
                  Navigator.pop(modalContext);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Transférer vers la tontine ──────────────────────────────────────────────

  void _showTransferToTontineSheet(
    BuildContext context,
    DashboardLoaded state,
  ) {
    final dashboardBloc = context.read<DashboardBloc>();
    final controller = TextEditingController();
    String? errorMessage;
    final cycle = state.tontineCycle;
    final hasActiveCycle =
        cycle != null && cycle.status == TontineCycleStatus.active;
    final remaining =
        hasActiveCycle ? cycle.targetAmount - cycle.cumulativeAmount : 0.0;
    final maxAmount =
        remaining < state.availableBalance ? remaining : state.availableBalance;

    _showActionSheet(
      context,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return _ActionSheetBody(
            title: "Vers la tontine",
            subtitle:
                "Disponible : ${formatFCFA(state.availableBalance)} F CFA",
            children: [
              if (!hasActiveCycle)
                const _InlineSheetError(
                  message:
                      "Aucune tontine active pour recevoir ce montant. Démarrez d'abord une tontine.",
                )
              else ...[
                _InfoBanner(
                  icon: Icons.flag_outlined,
                  text:
                      "Reste ${formatFCFA(remaining)} F pour atteindre l'objectif du cycle.",
                ),
                const SizedBox(height: 14),
                const _SheetLabel("Montant"),
                _AmountInput(
                  controller: controller,
                  onChanged: () => setModalState(() => errorMessage = null),
                ),
                const SizedBox(height: 10),
                _QuickAmountChips(
                  controller: controller,
                  maxAmount: maxAmount,
                  step: AppInputRules.financialAmountStep,
                  onSelected: () => setModalState(() => errorMessage = null),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineSheetError(message: errorMessage!),
              ],
              const SizedBox(height: 14),
              _SheetHint(
                "Multiple de ${AppInputRules.financialAmountStep} F. Confirmation par votre code PIN.",
              ),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: "Transférer",
                onPressed: () async {
                  if (!hasActiveCycle) {
                    setModalState(
                      () => errorMessage =
                          "Aucune tontine active pour ce transfert.",
                    );
                    return;
                  }

                  final amount = double.tryParse(controller.text);
                  if (amount == null || amount <= 0) {
                    setModalState(() => errorMessage = "Montant invalide.");
                    return;
                  }
                  if (amount % AppInputRules.financialAmountStep != 0) {
                    setModalState(
                      () => errorMessage =
                          "Le montant doit être un multiple de ${AppInputRules.financialAmountStep}.",
                    );
                    return;
                  }
                  if (amount > state.availableBalance) {
                    setModalState(
                      () => errorMessage = "Solde disponible insuffisant.",
                    );
                    return;
                  }
                  if (amount > remaining) {
                    setModalState(
                      () => errorMessage =
                          "Le montant dépasse l'objectif restant.",
                    );
                    return;
                  }

                  final authorized =
                      await LocalSecurityService.authorizeIfEnabled(
                        context,
                        title: 'Transférer vers la tontine',
                        message:
                            "Entrez votre PIN pour confirmer ce transfert vers votre tontine.",
                      );
                  if (!context.mounted || !authorized) {
                    return;
                  }

                  dashboardBloc.add(TransferToTontine(amount));
                  Navigator.pop(modalContext);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Demander un retrait ─────────────────────────────────────────────────────

  Future<void> _showWithdrawalSheet(
    BuildContext context,
    DashboardLoaded state,
  ) async {
    final dashboardBloc = context.read<DashboardBloc>();
    final service = RemoteDashboardService();
    final fetchedMethods = await service.fetchPaymentMethods('withdrawal');
    final paymentMethods = fetchedMethods
        .where(
          (method) =>
              method.code == 'agent_cash' ||
              method.code == 'mobile_money' ||
              method.code == 'bank_transfer',
        )
        .toList();

    if (!context.mounted) {
      return;
    }
    if (paymentMethods.isEmpty) {
      _showSnackBar(
        context,
        'Aucune méthode de retrait disponible pour le moment.',
      );
      return;
    }

    final controller = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;
    String selectedChannel = paymentMethods.first.code;

    try {
      await _showActionSheet(
        context,
        isDismissible: () => !isSubmitting,
        builder: (modalContext) => StatefulBuilder(
          builder: (context, setModalState) {
            return _ActionSheetBody(
              title: 'Demander un retrait',
              subtitle:
                  'Disponible : ${formatFCFA(state.availableBalance)} F CFA',
              children: [
                const _SheetLabel('Méthode de retrait'),
                ...paymentMethods.map(
                  (method) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChoiceTile(
                      icon: _withdrawalChannelIcon(method.code),
                      iconColor: AppTheme.primaryColor,
                      title: method.label,
                      subtitle: method.description ??
                          _withdrawalChannelHint(method.code),
                      selected: method.code == selectedChannel,
                      onTap: isSubmitting
                          ? null
                          : () => setModalState(() {
                              selectedChannel = method.code;
                              errorMessage = null;
                            }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const _SheetLabel('Montant'),
                _AmountInput(
                  controller: controller,
                  enabled: !isSubmitting,
                  onChanged: () => setModalState(() => errorMessage = null),
                ),
                const SizedBox(height: 10),
                _QuickAmountChips(
                  controller: controller,
                  maxAmount: state.availableBalance,
                  step: AppInputRules.financialAmountStep,
                  onSelected: () => setModalState(() => errorMessage = null),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _InlineSheetError(message: errorMessage!),
                ],
                const SizedBox(height: 14),
                _SheetHint(
                  "Le montant est réservé dès la demande. Multiple de ${AppInputRules.financialAmountStep} F, confirmation par votre code PIN.",
                ),
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'Confirmer le retrait',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amount = double.tryParse(controller.text);
                          if (amount == null || amount <= 0) {
                            setModalState(
                              () => errorMessage = 'Montant invalide.',
                            );
                            return;
                          }
                          if (amount % AppInputRules.financialAmountStep != 0) {
                            setModalState(
                              () => errorMessage =
                                  'Le montant doit être un multiple de ${AppInputRules.financialAmountStep}.',
                            );
                            return;
                          }
                          if (amount > state.availableBalance) {
                            setModalState(
                              () => errorMessage =
                                  'Solde disponible insuffisant.',
                            );
                            return;
                          }

                          final authorized =
                              await LocalSecurityService.authorizeIfEnabled(
                                context,
                                title: 'Demander un retrait',
                                message:
                                    'Entrez votre PIN pour confirmer cette demande de retrait.',
                              );
                          if (!context.mounted || !authorized) {
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          try {
                            final result = await service.requestWithdrawal(
                              amount,
                              channel: selectedChannel,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.pop(modalContext);
                            dashboardBloc.add(LoadDashboardData());
                            await _showWithdrawalSummarySheet(context, result);
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            setModalState(() {
                              errorMessage = _errorText(
                                error,
                                "Le retrait n'a pas pu être initié.",
                              );
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showWithdrawalSummarySheet(
    BuildContext context,
    WithdrawalRequestResult result,
  ) {
    return _showActionSheet(
      context,
      builder: (sheetContext) => _ActionSheetBody(
        title: result.requiresConfirmationCode
            ? 'Retrait initialisé'
            : 'Demande de retrait enregistrée',
        leading: const _StatusIcon(
          icon: Icons.check_rounded,
          color: AppTheme.successColor,
        ),
        children: [
          _InfoLine(
            label: 'Montant',
            value: '${formatFCFA(result.amount)} F',
            isHighlighted: true,
          ),
          _InfoLine(
            label: 'Méthode',
            value: _withdrawalChannelLabel(result.channel),
          ),
          _InfoLine(label: 'Référence', value: result.reference),
          if (result.requiresConfirmationCode) ...[
            if (result.confirmationCode != null)
              _InfoLine(
                label: 'Code client',
                value: result.confirmationCode!,
                isHighlighted: true,
              ),
            if (result.confirmationCodeExpiresAt != null)
              _InfoLine(
                label: "Valable jusqu'au",
                value: _formatDate(result.confirmationCodeExpiresAt!),
              ),
          ],
          const SizedBox(height: 6),
          _SheetHint(
            !result.requiresConfirmationCode
                ? "Votre demande a été transmise. L'administration la vérifiera avant de procéder au paiement."
                : result.channel == 'agent_cash'
                    ? "Montrez le QR code à votre agent pour recevoir votre argent."
                    : "Communiquez la référence à l'agent et gardez ce code pour confirmer le paiement.",
          ),
          const SizedBox(height: 16),
          if (result.requiresConfirmationCode &&
              result.channel == 'agent_cash') ...[
            _PrimaryButton(
              label: 'Voir mon QR code',
              icon: Icons.qr_code_rounded,
              onPressed: () => WithdrawalQrModal.show(sheetContext, result),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'Copier',
                  icon: Icons.copy_rounded,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: result.requiresConfirmationCode
                            ? 'Référence : ${result.reference} | Code : ${result.confirmationCode ?? ""}'
                            : 'Référence : ${result.reference} | Méthode : ${_withdrawalChannelLabel(result.channel)}',
                      ),
                    );
                    if (context.mounted) {
                      _showSnackBar(
                        context,
                        result.requiresConfirmationCode
                            ? 'Référence et code copiés.'
                            : 'Référence copiée.',
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SecondaryButton(
                  label: 'Fermer',
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Détail d'une opération ──────────────────────────────────────────────────

  Future<void> _showHistoryDetailSheet(
    BuildContext context,
    AvailableBalanceHistoryEntry entry,
    List<WithdrawalSummary> withdrawals,
  ) async {
    final linkedWithdrawal = _findLinkedWithdrawal(entry, withdrawals);
    final dashboardBloc = context.read<DashboardBloc>();
    final service = RemoteDashboardService();
    bool isSubmitting = false;

    await _showActionSheet(
      context,
      isDismissible: () => !isSubmitting,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final withdrawal = linkedWithdrawal;
          final canRegenerate = withdrawal != null &&
              withdrawal.status == 'requested' &&
              withdrawal.channel == 'agent_cash' &&
              withdrawal.isConfirmationCodeExpired;
          final canShowQr = withdrawal != null &&
              withdrawal.status == 'requested' &&
              withdrawal.channel == 'agent_cash' &&
              !withdrawal.isConfirmationCodeExpired;
          final canCancel =
              withdrawal != null && withdrawal.status == 'requested';

          return _ActionSheetBody(
            title: entry.label,
            leading: _StatusIcon(
              icon: entry.isCredit
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: entry.isCredit
                  ? AppTheme.successColor
                  : AppTheme.primaryColor,
            ),
            trailing: withdrawal == null
                ? null
                : _StatusChip(
                    label: _withdrawalStatusLabel(
                      withdrawal.status,
                      withdrawal.channel,
                    ),
                    color: _withdrawalStatusColor(withdrawal.status),
                  ),
            children: [
              _InfoLine(
                label: 'Montant',
                value:
                    '${entry.isCredit ? '+' : '−'} ${formatFCFA(entry.amount)} F',
                isHighlighted: true,
              ),
              _InfoLine(label: 'Date', value: _formatDate(entry.date)),
              _InfoLine(
                label: 'Sens',
                value: entry.isCredit ? 'Entrée' : 'Sortie',
              ),
              if (withdrawal != null) ...[
                _InfoLine(label: 'Référence', value: withdrawal.reference),
                _InfoLine(
                  label: 'Méthode',
                  value: _withdrawalChannelLabel(withdrawal.channel),
                ),
                if (withdrawal.channel == 'agent_cash' &&
                    withdrawal.confirmationCodeExpiresAt != null)
                  _InfoLine(
                    label: "Code valable jusqu'au",
                    value: withdrawal.isConfirmationCodeExpired
                        ? 'Expiré'
                        : _formatDate(withdrawal.confirmationCodeExpiresAt!),
                  ),
                if (withdrawal.approvedAt != null)
                  _InfoLine(
                    label: 'Approuvé le',
                    value: _formatDate(withdrawal.approvedAt!),
                  ),
                if (withdrawal.paidAt != null)
                  _InfoLine(
                    label: 'Payé le',
                    value: _formatDate(withdrawal.paidAt!),
                  ),
                if ((withdrawal.paymentReference ?? '').isNotEmpty)
                  _InfoLine(
                    label: 'Référence paiement',
                    value: withdrawal.paymentReference!,
                  ),
                if ((withdrawal.paymentProofImageUrl ?? '').isNotEmpty)
                  const _InfoLine(label: 'Preuve', value: 'Ajoutée'),
                if (withdrawal.cancelledAt != null)
                  _InfoLine(
                    label: 'Annulé le',
                    value: _formatDate(withdrawal.cancelledAt!),
                  ),
                if (withdrawal.rejectedAt != null)
                  _InfoLine(
                    label: 'Refusé le',
                    value: _formatDate(withdrawal.rejectedAt!),
                  ),
                if ((withdrawal.rejectionReason ?? '').isNotEmpty)
                  _InfoLine(
                    label: 'Motif de refus',
                    value: withdrawal.rejectionReason!,
                  ),
                if ((withdrawal.cancellationReason ?? '').isNotEmpty)
                  _InfoLine(
                    label: 'Motif',
                    value: withdrawal.cancellationReason!,
                  ),
                if (withdrawal.status == 'requested' &&
                    withdrawal.channel != 'agent_cash')
                  const _SheetHint(
                    "La demande est en attente de validation par l'administration.",
                  ),
              ],
              const SizedBox(height: 16),
              if (canShowQr) ...[
                _PrimaryButton(
                  label: 'Voir mon QR code',
                  icon: Icons.qr_code_rounded,
                  onPressed: isSubmitting
                      ? null
                      : () => WithdrawalQrModal.show(
                            sheetContext,
                            _resultFromSummary(withdrawal),
                          ),
                ),
                const SizedBox(height: 10),
              ],
              if (canRegenerate) ...[
                _PrimaryButton(
                  label: 'Générer un nouveau code',
                  icon: Icons.refresh_rounded,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setSheetState(() => isSubmitting = true);
                          final done = await _regenerateWithdrawalCode(
                            context,
                            withdrawal,
                            beforeSummary: () => Navigator.pop(sheetContext),
                          );
                          if (!done && context.mounted) {
                            setSheetState(() => isSubmitting = false);
                          }
                        },
                ),
                const SizedBox(height: 10),
              ],
              if (canCancel) ...[
                _SecondaryButton(
                  label: 'Annuler le retrait',
                  color: AppTheme.errorColor,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final authorized =
                              await LocalSecurityService.authorizeIfEnabled(
                                context,
                                title: 'Annuler le retrait',
                                message:
                                    "Entrez votre PIN pour annuler cette demande de retrait.",
                              );
                          if (!context.mounted || !authorized) {
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          try {
                            await service.cancelWithdrawal(withdrawal.id);
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.pop(sheetContext);
                            dashboardBloc.add(LoadDashboardData());
                            _showSnackBar(context, 'Retrait annulé.');
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            _showSnackBar(
                              context,
                              _errorText(
                                error,
                                "Le retrait n'a pas pu être annulé.",
                              ),
                            );
                            setSheetState(() => isSubmitting = false);
                          }
                        },
                ),
                const SizedBox(height: 10),
              ],
              _SecondaryButton(
                label: 'Fermer',
                onPressed:
                    isSubmitting ? null : () => Navigator.pop(sheetContext),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Régénère le code d'un retrait agent expiré puis affiche le récapitulatif.
  /// Retourne true si le nouveau code a été généré.
  Future<bool> _regenerateWithdrawalCode(
    BuildContext context,
    WithdrawalSummary withdrawal, {
    VoidCallback? beforeSummary,
  }) async {
    final dashboardBloc = context.read<DashboardBloc>();
    final authorized = await LocalSecurityService.authorizeIfEnabled(
      context,
      title: 'Régénérer le code',
      message:
          "Entrez votre PIN pour régénérer le code de confirmation du retrait.",
    );
    if (!context.mounted || !authorized) {
      return false;
    }
    try {
      final result =
          await RemoteDashboardService().regenerateWithdrawalCode(withdrawal.id);
      if (!context.mounted) {
        return true;
      }
      beforeSummary?.call();
      dashboardBloc.add(LoadDashboardData());
      await _showWithdrawalSummarySheet(context, result);
      return true;
    } catch (error) {
      if (context.mounted) {
        _showSnackBar(
          context,
          _errorText(error, "Le nouveau code n'a pas pu être généré."),
        );
      }
      return false;
    }
  }

  WithdrawalSummary? _findLinkedWithdrawal(
    AvailableBalanceHistoryEntry entry,
    List<WithdrawalSummary> withdrawals,
  ) {
    final match = RegExp(r'WDR-[A-Z0-9-]+').firstMatch(entry.label);
    final reference = match?.group(0);
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

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Fonctions utilitaires ─────────────────────────────────────────────────────

/// Le QR code de retrait ne contient que la référence : il peut être
/// reconstruit depuis le résumé du retrait.
WithdrawalRequestResult _resultFromSummary(WithdrawalSummary withdrawal) {
  return WithdrawalRequestResult(
    id: withdrawal.id,
    reference: withdrawal.reference,
    amount: withdrawal.amount,
    status: withdrawal.status,
    channel: withdrawal.channel,
    confirmationCodeExpiresAt: withdrawal.confirmationCodeExpiresAt,
    requestedAt: withdrawal.requestedAt,
    requiresConfirmationCode: true,
  );
}

Future<void> _showActionSheet(
  BuildContext context, {
  required WidgetBuilder builder,
  bool Function()? isDismissible,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PopScope(
      canPop: isDismissible?.call() ?? true,
      child: builder(sheetContext),
    ),
  );
}

String _errorText(Object error, String fallback) {
  return error is Exception
      ? error.toString().replaceFirst('Exception: ', '')
      : fallback;
}

String _formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} à ${two(value.hour)}:${two(value.minute)}';
}

String _withdrawalStatusLabel(String status, String channel) {
  switch (status) {
    case 'requested':
      return channel == 'agent_cash'
          ? 'En attente de paiement'
          : 'En attente de validation';
    case 'approved':
      return 'Approuvé';
    case 'paid':
      return 'Payé';
    case 'rejected':
      return 'Refusé';
    case 'cancelled':
      return 'Annulé';
    default:
      return status;
  }
}

Color _withdrawalStatusColor(String status) {
  switch (status) {
    case 'paid':
      return AppTheme.successColor;
    case 'rejected':
    case 'cancelled':
      return AppTheme.errorColor;
    case 'approved':
      return AppTheme.infoColor;
    default:
      return AppTheme.warningColor;
  }
}

String _withdrawalChannelLabel(String channel) {
  switch (channel) {
    case 'agent_cash':
      return 'Agent VizioBox';
    case 'mobile_money':
      return 'Mobile Money';
    case 'bank_transfer':
      return 'Virement bancaire';
    default:
      return channel;
  }
}

IconData _withdrawalChannelIcon(String channel) {
  switch (channel) {
    case 'agent_cash':
      return Icons.storefront_outlined;
    case 'mobile_money':
      return Icons.phone_android_rounded;
    case 'bank_transfer':
      return Icons.account_balance_outlined;
    default:
      return Icons.payments_outlined;
  }
}

String _withdrawalChannelHint(String channel) {
  switch (channel) {
    case 'agent_cash':
      return "Présentez votre QR code à un agent qui vous remet l'argent.";
    case 'mobile_money':
      return "Validation par l'administration puis paiement Mobile Money.";
    case 'bank_transfer':
      return "Validation par l'administration puis paiement par virement.";
    default:
      return '';
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ── En-tête ───────────────────────────────────────────────────────────────────

class _BalanceHeroSummary extends StatelessWidget {
  final double availableBalance;
  final double reservedAmount;
  final int goalsCount;

  const _BalanceHeroSummary({
    required this.availableBalance,
    required this.reservedAmount,
    required this.goalsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Disponible maintenant",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatFCFA(availableBalance),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "F CFA",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.schedule_rounded,
                  label: "Réservé retrait",
                  value: "${formatFCFA(reservedAmount)} F",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.savings_outlined,
                  label: "Coffres actifs",
                  value: goalsCount.toString(),
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
  final IconData icon;
  final String label;
  final String value;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

// ── Cartes de l'écran ─────────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onFundGoal;
  final VoidCallback onTransferToTontine;
  final VoidCallback onWithdraw;

  const _QuickActionsCard({
    required this.onFundGoal,
    required this.onTransferToTontine,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.savings_outlined,
            label: "Vers un coffre",
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
            iconColor: AppTheme.primaryColor,
            onTap: onFundGoal,
          ),
          _QuickAction(
            icon: Icons.autorenew_rounded,
            label: "Vers la tontine",
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
            iconColor: AppTheme.accentDarkColor,
            onTap: onTransferToTontine,
          ),
          _QuickAction(
            icon: Icons.payments_outlined,
            label: "Retirer",
            backgroundColor: AppTheme.primaryColor,
            iconColor: Colors.white,
            onTap: onWithdraw,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingWithdrawalCard extends StatelessWidget {
  final WithdrawalSummary withdrawal;
  final int otherCount;
  final VoidCallback onShowQr;
  final VoidCallback onRegenerateCode;

  const _PendingWithdrawalCard({
    required this.withdrawal,
    required this.otherCount,
    required this.onShowQr,
    required this.onRegenerateCode,
  });

  @override
  Widget build(BuildContext context) {
    final isAgentWithdrawal =
        withdrawal.channel == 'agent_cash' && withdrawal.status == 'requested';
    final codeExpired = withdrawal.isConfirmationCodeExpired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppTheme.accentDarkColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Retrait en cours · ${formatFCFA(withdrawal.amount)} F",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAgentWithdrawal && codeExpired
                          ? "Code expiré : générez-en un nouveau."
                          : _withdrawalStatusLabel(
                              withdrawal.status,
                              withdrawal.channel,
                            ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (otherCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              otherCount == 1
                  ? "+ 1 autre retrait en cours (voir l'historique)"
                  : "+ $otherCount autres retraits en cours (voir l'historique)",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.accentDarkColor,
              ),
            ),
          ],
          if (isAgentWithdrawal) ...[
            const SizedBox(height: 12),
            _PrimaryButton(
              label: codeExpired ? "Générer un nouveau code" : "Voir mon QR code",
              icon: codeExpired ? Icons.refresh_rounded : Icons.qr_code_rounded,
              height: 44,
              onPressed: codeExpired ? onRegenerateCode : onShowQr,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}

// ── Éléments des fenêtres ─────────────────────────────────────────────────────

class _ActionSheetBody extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;

  const _ActionSheetBody({
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
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
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ],
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }
}

class _SheetHint extends StatelessWidget {
  final String text;

  const _SheetHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _ChoiceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool enabled;

  const _AmountInput({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor, width: 1.6),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: AppInputRules.amountFormatters,
              onChanged: (_) => onChanged(),
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: "0",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.borderColor,
                ),
              ),
            ),
          ),
          Text(
            "F CFA",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentDarkColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountChips extends StatelessWidget {
  static const _presets = [1000.0, 5000.0, 10000.0];

  final TextEditingController controller;
  final double maxAmount;
  final int step;
  final VoidCallback onSelected;

  const _QuickAmountChips({
    required this.controller,
    required this.maxAmount,
    required this.onSelected,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    // « Tout » = le maximum autorisé, arrondi au pas inférieur.
    final allAmount = (maxAmount / step).floorToDouble() * step;
    final presets = _presets.where((value) => value < allAmount).toList();
    final current = double.tryParse(controller.text);

    Widget chip(String label, double value, {bool accent = false}) {
      final selected = current == value;
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          controller.text = value.toStringAsFixed(0);
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
          onSelected();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor
                : accent
                    ? AppTheme.accentColor.withValues(alpha: 0.15)
                    : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : accent
                      ? AppTheme.accentDarkColor
                      : AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }

    if (allAmount <= 0) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...presets.map((value) => chip(formatFCFA(value), value)),
        chip("Tout", allAmount, accent: true),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          // Le thème global impose un rembourrage vertical trop grand pour 44 px.
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
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
                fontSize: isHighlighted ? 15 : 14,
                fontWeight: FontWeight.w700,
                color: isHighlighted
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
