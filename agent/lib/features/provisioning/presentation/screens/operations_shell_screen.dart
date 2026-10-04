import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_start_tontine_sheet.dart';
import 'package:agent/features/history/presentation/screens/history_screen.dart';
import 'package:agent/features/provisioning/presentation/widgets/agent_client_search_sheet.dart';
import 'package:agent/features/provisioning/presentation/widgets/agent_deposit_sheet.dart';
import 'package:agent/features/withdrawals/presentation/widgets/agent_withdrawal_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';

class OperationsShellScreen extends StatefulWidget {
  const OperationsShellScreen({super.key});

  @override
  State<OperationsShellScreen> createState() => _OperationsShellScreenState();
}

class _OperationsShellScreenState extends State<OperationsShellScreen> {
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Opérations'),
        actions: [
          IconButton(
            onPressed: () {
              _historyKey.currentState?.openFiltersSheet();
            },
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Rechercher et filtrer',
          ),
        ],
      ),
      body: HistoryScreen(key: _historyKey, isEmbedded: true),
      floatingActionButton: SpeedDial(
        icon: Icons.add_rounded,
        activeIcon: Icons.close_rounded,
        backgroundColor: AgentAppTheme.accentColor,
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        spacing: 12,
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.download_rounded, color: AgentAppTheme.primaryColor),
            backgroundColor: const Color(0xFFE6EBF2),
            label: 'Faire un dépôt',
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            onTap: _openClientSearch,
          ),
          SpeedDialChild(
            child: const Icon(Icons.payments_outlined, color: Color(0xFFFF472B)),
            backgroundColor: const Color(0xFFFFF0ED),
            label: 'Payer un retrait',
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            onTap: _openWithdrawalSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _openClientSearch() async {
    final client = await showModalBottomSheet<AgentClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentClientSearchSheet(),
    );

    if (!mounted || client == null) {
      return;
    }

    _handleClientSelection(client);
  }

  Future<void> _openWithdrawalSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentWithdrawalPaymentSheet(),
    );

    if (!mounted || result != true) {
      return;
    }

    _showMessage('Retrait payé avec succès.');
    // Force history refresh if needed
  }

  Future<void> _handleClientSelection(AgentClient client) async {
    if (client.hasActiveTontine) {
      final result = await showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AgentDepositSheet(client: client),
      );

      if (mounted && result == true) {
        _showMessage('Dépôt enregistré avec succès.');
        // Force history refresh if needed
      } else if (mounted && result == 'BACK') {
        _openClientSearch();
      }
      return;
    }

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentStartTontineSheet(client: client),
    );

    if (mounted && result != null && result != 'BACK') {
      _showMessage('Tontine démarrée avec succès.');
      // Force history refresh if needed
    } else if (mounted && result == 'BACK') {
      _openClientSearch();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
