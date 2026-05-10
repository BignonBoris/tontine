import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

void showScanSimulation(BuildContext context, DashboardBloc bloc) {
  final amountController = TextEditingController();
  String? selectedGoalId;
  String? errorMessage;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => StatefulBuilder(
      builder: (context, setModalState) {
        void showInlineError(String message) {
          setModalState(() => errorMessage = message);
        }

        void clearInlineError() {
          if (errorMessage != null) {
            setModalState(() => errorMessage = null);
          }
        }

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 30,
            left: 25,
            right: 25,
            top: 25,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Faire un depot",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Alimentez un coffre depuis votre solde disponible.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
              const SizedBox(height: 25),
              BlocBuilder<DashboardBloc, DashboardState>(
                bloc: bloc,
                builder: (context, state) {
                  if (state is DashboardLoaded) {
                    if (state.goals.isEmpty) {
                      return Text(
                        "Aucun coffre actif disponible.",
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      );
                    }

                    selectedGoalId ??= state.goals.first.id;
                    return DropdownButtonFormField<String>(
                      value: selectedGoalId,
                      decoration: InputDecoration(
                        labelText: "Choisir le coffre a alimenter",
                        helperText:
                            "Disponible : ${formatFCFA(state.availableBalance)} F",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      items: state.goals
                          .map(
                            (goal) => DropdownMenuItem(
                              value: goal.id,
                              child: Text(goal.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        clearInlineError();
                        setModalState(() => selectedGoalId = value);
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => clearInlineError(),
                decoration: InputDecoration(
                  labelText: "Montant a deposer (F CFA)",
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                _BottomSheetInlineError(message: errorMessage!),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    final state = bloc.state;

                    if (state is! DashboardLoaded) {
                      showInlineError("Donnees indisponibles pour le moment.");
                      return;
                    }

                    if (state.goals.isEmpty || selectedGoalId == null) {
                      showInlineError("Aucun coffre actif disponible.");
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      showInlineError("Montant invalide.");
                      return;
                    }

                    if (amount > state.availableBalance) {
                      showInlineError("Solde disponible insuffisant.");
                      return;
                    }

                    final selectedGoal = state.goals.firstWhere(
                      (goal) => goal.id == selectedGoalId,
                    );
                    final remaining =
                        selectedGoal.targetAmount - selectedGoal.currentAmount;

                    if (amount > remaining) {
                      showInlineError(
                        "Le montant depasse l'objectif restant du coffre.",
                      );
                      return;
                    }

                    bloc.add(AddFundsToGoal(selectedGoalId!, amount));
                    Navigator.pop(modalContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Depot enregistre avec succes !"),
                      ),
                    );
                  },
                  child: const Text(
                    "Confirmer le depot",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _BottomSheetInlineError extends StatelessWidget {
  final String message;

  const _BottomSheetInlineError({required this.message});

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
