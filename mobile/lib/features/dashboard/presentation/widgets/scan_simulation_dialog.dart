import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

void showScanSimulation(BuildContext context, DashboardBloc bloc) {
  final amountController = TextEditingController();
  String? selectedGoalId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => Container(
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
                  onChanged: (value) => selectedGoalId = value,
                );
              }

              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: const [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Montant a deposer (F CFA)",
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                final state = bloc.state;

                if (state is! DashboardLoaded) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    const SnackBar(
                      content: Text("Donnees indisponibles pour le moment."),
                    ),
                  );
                  return;
                }

                if (state.goals.isEmpty || selectedGoalId == null) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    const SnackBar(
                      content: Text("Aucun coffre actif disponible."),
                    ),
                  );
                  return;
                }

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    const SnackBar(content: Text("Montant invalide.")),
                  );
                  return;
                }

                if (amount > state.availableBalance) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    const SnackBar(
                      content: Text("Solde disponible insuffisant."),
                    ),
                  );
                  return;
                }

                final selectedGoal = state.goals.firstWhere(
                  (goal) => goal.id == selectedGoalId,
                );
                final remaining =
                    selectedGoal.targetAmount - selectedGoal.currentAmount;

                if (amount > remaining) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Le montant depasse l'objectif restant du coffre.",
                      ),
                    ),
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
    ),
  );
}
