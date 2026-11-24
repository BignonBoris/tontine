import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/data/services/tontine_fedapay_service.dart';
import 'package:mobile/features/dashboard/presentation/widgets/fedapay_push_waiting_screen.dart';

class _FakeFedapayService extends TontineFedapayService {
  TontineFedapayDepositIntent next;

  _FakeFedapayService(this.next);

  @override
  Future<TontineFedapayDepositIntent> fetchDepositIntent(String intentId) async =>
      next;
}

TontineFedapayDepositIntent _intent({
  String status = 'pending',
  String? providerStatus = 'pending',
  String? failureMessage,
}) {
  return TontineFedapayDepositIntent(
    id: 'intent-1',
    amount: 5000,
    status: status,
    merchantReference: 'TT-1',
    providerStatus: providerStatus,
    channel: 'push',
    pushOperator: 'mtn',
    pushPhoneMasked: '01••••••90',
    failureMessage: failureMessage,
  );
}

Future<FedapayPushOutcome?> _pumpScreen(
  WidgetTester tester,
  _FakeFedapayService service,
) async {
  FedapayPushOutcome? outcome;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              outcome = await Navigator.of(context).push<FedapayPushOutcome>(
                MaterialPageRoute(
                  builder: (_) => FedapayPushWaitingScreen(
                    intent: _intent(),
                    operatorLabel: 'MTN MoMo',
                    service: service,
                  ),
                ),
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return outcome;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('affiche l attente puis la confirmation', (tester) async {
    final service = _FakeFedapayService(_intent());
    await _pumpScreen(tester, service);

    expect(find.text('Validez le paiement sur votre téléphone'), findsOneWidget);
    expect(find.textContaining('01••••••90'), findsOneWidget);

    service.next = _intent(status: 'processed', providerStatus: 'approved');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Paiement confirmé'), findsOneWidget);
  });

  testWidgets('affiche le message de refus et propose les alternatives', (tester) async {
    final service = _FakeFedapayService(
      _intent(
        status: 'cancelled',
        providerStatus: 'canceled',
        failureMessage: 'Solde Mobile Money insuffisant.',
      ),
    );
    await _pumpScreen(tester, service);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Paiement non abouti'), findsOneWidget);
    expect(find.text('Solde Mobile Money insuffisant.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Payer autrement (page FedaPay)'), findsOneWidget);
  });

  testWidgets('le renvoi n est possible qu apres le delai', (tester) async {
    final service = _FakeFedapayService(_intent());
    await _pumpScreen(tester, service);

    final resend = find.byType(OutlinedButton);
    expect(tester.widget<OutlinedButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 31));
    expect(tester.widget<OutlinedButton>(resend).onPressed, isNotNull);
    expect(find.text('Rien reçu ? Renvoyer la demande'), findsOneWidget);

    // Ferme l'ecran pour arreter les minuteries.
    await tester.tap(find.text('Fermer').first);
    await tester.pumpAndSettle();
  });
}
