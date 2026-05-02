import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Ajouté pour FilteringTextInputFormatter
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

void showScanSimulation(BuildContext context, DashboardBloc bloc) {
  final TextEditingController amountController = TextEditingController();
  String? selectedGoalId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
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
            "Faire un dépôt",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Enregistrez votre versement auprès de l'agent",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey[600]),
          ),
          const SizedBox(height: 25),

          BlocBuilder<DashboardBloc, DashboardState>(
            bloc: bloc,
            builder: (context, state) {
              if (state is DashboardLoaded) {
                selectedGoalId ??= state.goals.first.id;
                return DropdownButtonFormField<String>(
                  value: selectedGoalId,
                  decoration: InputDecoration(
                    labelText: "Choisir le coffre de destination",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  items: state.goals
                      .map(
                        (g) =>
                            DropdownMenuItem(value: g.id, child: Text(g.title)),
                      )
                      .toList(),
                  onChanged: (val) => selectedGoalId = val,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ], // Sécurité : chiffres uniquement
            decoration: InputDecoration(
              labelText: "Montant déposé (F CFA)",
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
                final double? amt = double.tryParse(amountController.text);
                if (amt != null && amt > 0 && selectedGoalId != null) {
                  bloc.add(MakeDeposit(goalId: selectedGoalId!, amount: amt));

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Dépôt enregistré avec succès !"),
                    ),
                  );
                }
              },
              child: const Text(
                "Confirmer le versement",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
