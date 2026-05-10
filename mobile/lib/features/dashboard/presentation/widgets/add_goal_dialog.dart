import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';

void showAddGoalDialog(BuildContext context, DashboardBloc bloc) {
  final nameController = TextEditingController();
  final targetController = TextEditingController();
  DateTime selectedEndDate = DateTime.now().add(const Duration(days: 30));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Container(
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
            Text(
              "Nouveau Coffre",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Nom de l'objectif (ex: Mariage)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: "Montant cible (F CFA)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Nouveau champ de sélection de date (Design respecté)
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedEndDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  locale: const Locale("fr", "FR"),
                );
                if (picked != null) {
                  setState(() => selectedEndDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF1A237E)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Date d'échéance",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy').format(selectedEndDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
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
                  final target = double.tryParse(targetController.text) ?? 0;
                  if (nameController.text.isNotEmpty && target > 0) {
                    final newGoal = TontineGoal(
                      id: DateTime.now().toString(),
                      title: nameController.text,
                      targetAmount: target,
                      currentAmount: 0,
                      // REMPLACE icon par iconCodePoint
                      iconCodePoint: Icons.savings_rounded.codePoint,
                      // REMPLACE color par colorValue
                      colorValue: Colors.blueAccent.value,
                      startDate: DateTime.now(),
                      endDate: selectedEndDate,
                    );
                    bloc.add(AddGoal(newGoal));
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Créer le coffre",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
