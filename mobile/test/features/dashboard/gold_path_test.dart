import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Importe tes fichiers ici (adapte les chemins selon ton projet)
import 'package:mobile/features/dashboard/presentation/screens/goal_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';

void main() {
  group('Test du Flux de Dépôt (Golden Path)', () {
    testWidgets(
      'Validation : Impossible de déposer plus que le solde disponible',
      (WidgetTester tester) async {
        // 1. Initialise l'écran avec un solde fictif de 5000 F
        // On simule un état DashboardLoaded avec 5000 F dispo

        // 2. Ouvre le modal de dépôt
        await tester.tap(find.text('Déposer'));
        await tester.pumpAndSettle(); // Attend l'animation

        // 3. Saisie d'un montant trop grand (10 000 F)
        await tester.enterText(find.byType(TextField), '10000');

        // 4. Clic sur confirmer
        await tester.tap(find.text('Confirmer le dépôt'));
        await tester.pumpAndSettle();

        // 5. Vérification : On doit voir le message d'erreur et PAS le succès
        expect(find.textContaining('Solde insuffisant'), findsOneWidget);
      },
    );

    testWidgets('Succès : Un dépôt valide met à jour les données', (
      WidgetTester tester,
    ) async {
      // 1. Saisie d'un montant valide (1000 F)
      await tester.enterText(find.byType(TextField), '1000');

      // 2. Clic sur confirmer
      await tester.tap(find.text('Confirmer le dépôt'));
      await tester.pumpAndSettle();

      // 3. Vérification : Le modal doit se fermer
      expect(find.text('Effectuer un dépôt'), findsNothing);
      expect(find.text('Dépôt enregistré !'), findsOneWidget);
    });
  });
}
