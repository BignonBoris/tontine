import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';
import 'package:mobile/features/dashboard/domain/entities/profile_preferences.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Solde disponible simulé pour le scénario de test.
const double _soldeDisponible = 5000;

/// Titre du coffre simulé (utilisé pour retrouver la carte à l'écran).
const String _coffreTitre = 'École des enfants';

/// Fake du service distant : aucune vraie requête réseau n'est émise.
/// Les méthodes non redéfinies lèvent une erreur (fail-fast) grâce à
/// `noSuchMethod`, ce qui garantit que le test n'utilise que le flux simulé.
class _FakeRemoteDashboardService implements RemoteDashboardService {
  @override
  Future<RemoteDashboardSnapshot> fetchDashboardSnapshot() async {
    return RemoteDashboardSnapshot(
      goals: [_buildGoal()],
      availableBalance: _soldeDisponible,
      tontineBalance: 0,
      tontineCycle: null,
      tontineHistory: const [],
      tontineArchives: const [],
      availableBalanceHistory: const [],
      withdrawals: const [],
      marketOrders: const [],
      notifications: const [],
      favoriteOfferIds: const [],
      marketOffers: const [],
      profile: UserProfile.initial(phoneNumber: '+2290196000000'),
      preferences: const ProfilePreferences.defaults(),
    );
  }

  @override
  Future<void> fundGoal(String goalId, double amount) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TontineGoal _buildGoal() {
  return TontineGoal(
    id: 'goal-1',
    title: _coffreTitre,
    targetAmount: 50000,
    currentAmount: 10000,
    iconCodePoint: Icons.school_rounded.codePoint,
    colorValue: 0xFF1565C0,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
  );
}

Future<void> _pumpDashboard(WidgetTester tester, DashboardBloc bloc) async {
  bloc.add(LoadDashboardData());
  await tester.pumpWidget(
    BlocProvider<DashboardBloc>.value(
      value: bloc,
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // Interdit les téléchargements de polices en test (fallback local).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // Session simulée : évite les timers d'attente du service temps réel
    // et fournit le token attendu par l'en-tête du tableau de bord.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'authToken': 'test-token',
      'isLoggedIn': true,
      // La carte de bienvenue est déjà "vue" : le test se concentre sur le
      // flux de dépôt (elle est couverte visuellement à la main).
      'app.dashboard_welcome_seen': true,
    });
  });

  group('Test du Flux de Dépôt (Golden Path)', () {
    testWidgets(
      'Validation : Impossible de déposer plus que le solde disponible',
      (WidgetTester tester) async {
        final bloc = DashboardBloc(
          remoteDashboardService: _FakeRemoteDashboardService(),
        );
        addTearDown(bloc.close);

        await _pumpDashboard(tester, bloc);

        // Ouvre le modal de versement rapide depuis la carte du coffre.
        await tester.dragUntilVisible(
          find.text('Verser'),
          find.byType(Scrollable).first,
          const Offset(0, -120),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verser'));
        await tester.pumpAndSettle();

        expect(find.text('Alimenter le coffre'), findsOneWidget);

        // Saisie d'un montant supérieur au solde disponible (10 000 > 5 000).
        await tester.enterText(find.byType(TextField), '10000');
        await tester.tap(find.text('Confirmer le versement'));
        await tester.pumpAndSettle();

        // Le modal reste ouvert et le message d'erreur explicite est affiché.
        expect(find.text('Alimenter le coffre'), findsOneWidget);
        expect(find.text('Solde disponible insuffisant.'), findsOneWidget);

        // Laisse le snackbar se fermer (évite un timer en attente en fin de test).
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Succès : Un dépôt valide met à jour les données', (
      WidgetTester tester,
    ) async {
      final bloc = DashboardBloc(
        remoteDashboardService: _FakeRemoteDashboardService(),
      );
      addTearDown(bloc.close);

      await _pumpDashboard(tester, bloc);

      await tester.dragUntilVisible(
        find.text('Verser'),
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verser'));
      await tester.pumpAndSettle();

      // Saisie d'un montant valide (1 000 <= 5 000).
      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Confirmer le versement'));
      await tester.pumpAndSettle();

      // Le modal se ferme et la confirmation de versement est affichée
      // avec l'unité monétaire normalisée (FCFA).
      expect(find.text('Alimenter le coffre'), findsNothing);
      expect(find.textContaining('FCFA versé dans'), findsOneWidget);
      expect(find.textContaining(_coffreTitre), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}

