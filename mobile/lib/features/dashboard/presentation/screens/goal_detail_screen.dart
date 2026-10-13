import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_action_button.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';
import 'package:mobile/features/dashboard/presentation/widgets/finance_hero_header.dart';
import 'package:uuid/uuid.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late ConfettiController _confettiController;
  bool _isHistoryCalendarView = false;

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
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showDepositSheet(context, state, goal),
                backgroundColor: AppTheme.primaryColor,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Deposer",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              body: Column(
                children: [
                  FinanceHeroHeader(
                    title: goal.title,
                    titleFontSize: 18,
                    showBackButton: true,
                    actions: [
                      Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'close') {
                              _confirmClose(context, goal);
                            }
                          },
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'close',
                              child: Row(
                                children: [
                                  Icon(Icons.archive_outlined, color: AppTheme.errorColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cloturer le coffre',
                                    style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                                Row(
                                  children: [
                                    Text(
                                      "${formatFCFA(goal.currentAmount)} F",
                                      style: GoogleFonts.poppins(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: goal.color,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: goal.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.calendar_today_outlined, size: 14, color: goal.color),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${goal.remainingDays} j",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: goal.color,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _HeroMetric(
                                      label: "Progression",
                                      value: "${(goal.progress * 100).toInt()}%",
                                    ),
                                    _HeroMetric(
                                      label: "Reste",
                                      value:
                                          "${formatFCFA((goal.targetAmount - goal.currentAmount).toInt())} F",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(20, 20, 20, 100), // padding for FAB
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Historique",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => setState(() => _isHistoryCalendarView = false),
                                          child: Icon(
                                            Icons.list_rounded,
                                            color: !_isHistoryCalendarView ? AppTheme.primaryColor : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => setState(() => _isHistoryCalendarView = true),
                                          child: Icon(
                                            Icons.calendar_month_rounded,
                                            color: _isHistoryCalendarView ? AppTheme.primaryColor : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (goal.transactions.isEmpty)
                                  _buildEmptyHistory()
                                else if (_isHistoryCalendarView)
                                  _buildHistoryCalendar(goal)
                                else
                                  _buildTransactionList(goal),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                  inputFormatters: AppInputRules.amountFormatters,
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
                    onPressed: () async {
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

                      final authorized =
                          await LocalSecurityService.authorizeIfEnabled(
                            context,
                            title: 'Effectuer un depot',
                            message:
                                "Entrez votre PIN pour confirmer le depot vers ${goal.title}.",
                          );
                      if (!context.mounted || !authorized) {
                        return;
                      }

                      final syncId = const Uuid().v4();
                      context.read<DashboardBloc>().add(
                        AddFundsToGoal(goal.id, amount, syncId),
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

  Widget _buildHistoryCalendar(TontineGoal goal) {
    final transactionDays = goal.transactions.map((t) {
      return DateTime(t.date.year, t.date.month, t.date.day);
    }).toSet();

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppTheme.primaryColor,
          onPrimary: Colors.white,
          onSurface: AppTheme.primaryColor,
        ),
      ),
      child: CalendarDatePicker(
        initialDate: DateTime.now(),
        firstDate: goal.startDate,
        lastDate: goal.endDate.isAfter(DateTime.now()) ? goal.endDate : DateTime.now(),
        onDateChanged: (date) {},
        selectableDayPredicate: (date) {
          final day = DateTime(date.year, date.month, date.day);
          return transactionDays.contains(day);
        },
      ),
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

  void _confirmClose(BuildContext context, TontineGoal goal) async {
    final bool isEarlyClosure = goal.remainingDays > 0;
    num penaltyPercent = 0.0;

    // Chargement de la config de pénalité si clôture anticipée
    if (isEarlyClosure) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final config = await RemoteDashboardService().getGoalConfig();
        penaltyPercent = config['earlyClosurePenaltyPercent'] ?? 5.0;
        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        if (context.mounted) Navigator.pop(context);
        penaltyPercent = 5.0;
      }
    }

    if (!context.mounted) return;

    // Lancement du dialog stepper unique (3 étapes, zéro chevauchement)
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CloseGoalDialog(
        goal: goal,
        isEarlyClosure: isEarlyClosure,
        penaltyPercent: penaltyPercent,
        onSuccess: _confettiController.play,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de clôture avec stepper à 3 étapes (sans chevauchement de modaux)
// ─────────────────────────────────────────────────────────────────────────────

enum _CloseGoalStep { summary, pin, done }

class _CloseGoalDialog extends StatefulWidget {
  final TontineGoal goal;
  final bool isEarlyClosure;
  final num penaltyPercent;
  final VoidCallback onSuccess;

  const _CloseGoalDialog({
    required this.goal,
    required this.isEarlyClosure,
    required this.penaltyPercent,
    required this.onSuccess,
  });

  @override
  State<_CloseGoalDialog> createState() => _CloseGoalDialogState();
}

class _CloseGoalDialogState extends State<_CloseGoalDialog>
    with SingleTickerProviderStateMixin {
  _CloseGoalStep _step = _CloseGoalStep.summary;
  String _pin = '';
  bool _isSubmitting = false;
  bool _isPinError = false;
  String? _apiError;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  double get _penaltyAmount => widget.isEarlyClosure
      ? (widget.goal.currentAmount * widget.penaltyPercent / 100)
      : 0.0;

  double get _returnedAmount => widget.goal.currentAmount - _penaltyAmount;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ── Logique PIN ───────────────────────────────────────────────────────────

  void _onKey(String digit) {
    if (_isSubmitting || _pin.length >= 4) return;
    setState(() {
      _isPinError = false;
      _pin += digit;
    });
    if (_pin.length == 4) _submitClose();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submitClose() async {
    final isValid = await LocalSecurityService.verifyPin(_pin);
    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _isPinError = true;
        _pin = '';
      });
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      context.read<DashboardBloc>().add(CloseGoal(widget.goal.id));
      await context.read<DashboardBloc>().stream.firstWhere(
            (s) => s is DashboardLoaded || s is DashboardError,
          );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _step = _CloseGoalStep.done;
      });
      widget.onSuccess();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _apiError = 'Impossible de clôturer le coffre. Veuillez réessayer.';
        _step = _CloseGoalStep.done;
      });
    }
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────

  Widget _buildKey(String label, {Widget? icon, VoidCallback? onTap}) {
    final isEmpty = label.isEmpty && icon == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEmpty ? null : (onTap ?? () => _onKey(label)),
        customBorder: const CircleBorder(),
        splashColor: AppTheme.primaryColor.withOpacity(0.12),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isEmpty
                  ? Colors.transparent
                  : AppTheme.primaryColor.withOpacity(0.18),
            ),
          ),
          alignment: Alignment.center,
          child: icon ??
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryColor,
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, __) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPinError
                    ? AppTheme.errorColor
                    : filled
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.15),
                border: Border.all(
                  color: _isPinError
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _CloseGoalStep.pin || !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _CloseGoalStep.pin && !_isSubmitting) {
          setState(() {
            _step = _CloseGoalStep.summary;
            _pin = '';
            _isPinError = false;
          });
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: switch (_step) {
              _CloseGoalStep.summary => _buildSummaryStep(),
              _CloseGoalStep.pin     => _buildPinStep(),
              _CloseGoalStep.done    => _buildDoneStep(),
            },
          ),
        ),
      ),
    );
  }

  // ── Étape 1 : Résumé ──────────────────────────────────────────────────────
  Widget _buildSummaryStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEarlyClosure ? 'Clôture anticipée' : 'Clôturer le coffre ?',
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        if (widget.isEarlyClosure)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE57373)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFD32F2F), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clôturer avant l\'échéance entraîne une pénalité '
                    'de ${widget.penaltyPercent}% (${_penaltyAmount.toInt()} F).',
                    style: GoogleFonts.inter(
                        color: const Color(0xFFB71C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                label: 'Solde actuel',
                value: '${widget.goal.currentAmount.toInt()} F',
              ),
              if (widget.isEarlyClosure) ...[
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Pénalité',
                  value: '- ${_penaltyAmount.toInt()} F',
                  valueColor: AppTheme.errorColor,
                ),
              ],
              const Divider(height: 18),
              _SummaryRow(
                label: 'Vous recevrez',
                value: '${_returnedAmount.toInt()} F',
                bold: true,
                valueColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor),
                onPressed: () => setState(() => _step = _CloseGoalStep.pin),
                child: const Text('Continuer →',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Étape 2 : Clavier PIN ─────────────────────────────────────────────────
  Widget _buildPinStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: _isSubmitting ? Colors.grey : AppTheme.primaryColor,
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() {
                        _step = _CloseGoalStep.summary;
                        _pin = '';
                        _isPinError = false;
                      }),
            ),
            Expanded(
              child: Text(
                'Code de sécurité',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Entrez votre code PIN pour confirmer la clôture.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 20),
        _buildPinDots(),
        if (_isPinError) ...[
          const SizedBox(height: 8),
          Text(
            'Code PIN incorrect',
            style: GoogleFonts.inter(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 24),
        if (_isSubmitting)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              Text('Clôture en cours...',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor, fontSize: 13)),
              const SizedBox(height: 16),
            ],
          )
        else
          Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['1', '2', '3'].map(_buildKey).toList()),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['4', '5', '6'].map(_buildKey).toList()),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['7', '8', '9'].map(_buildKey).toList()),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKey('', icon: const SizedBox()),
                  _buildKey('0'),
                  _buildKey('',
                      icon: Icon(Icons.backspace_outlined,
                          color: AppTheme.primaryColor.withOpacity(0.7),
                          size: 24),
                      onTap: _onBackspace),
                ],
              ),
            ],
          ),
      ],
    );
  }

  // ── Étape 3 : Résultat ────────────────────────────────────────────────────
  Widget _buildDoneStep() {
    final isError = _apiError != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          size: 60,
          color: isError ? AppTheme.errorColor : AppTheme.successColor,
        ),
        const SizedBox(height: 16),
        Text(
          isError ? 'Échec de la clôture' : 'Coffre clôturé !',
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isError ? AppTheme.errorColor : AppTheme.successColor),
        ),
        const SizedBox(height: 10),
        Text(
          isError
              ? _apiError!
              : '${_returnedAmount.toInt()} F ont été reversés\nsur votre solde disponible.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppTheme.textSecondaryColor, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isError ? AppTheme.errorColor : AppTheme.successColor,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(isError ? 'Fermer' : 'Parfait !',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// Ligne de résumé label / valeur
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondaryColor)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppTheme.textPrimaryColor)),
      ],
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

  const _HeroMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label : ",
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
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
