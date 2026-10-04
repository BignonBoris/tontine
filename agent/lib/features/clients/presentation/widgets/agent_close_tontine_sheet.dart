import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/widgets/animated_bottom_sheet.dart';
import 'package:agent/core/widgets/client_pin_pad.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgentCloseTontineSheet extends StatefulWidget {
  final AgentClient client;

  const AgentCloseTontineSheet({super.key, required this.client});

  @override
  State<AgentCloseTontineSheet> createState() => _AgentCloseTontineSheetState();
}

class _AgentCloseTontineSheetState extends State<AgentCloseTontineSheet> {
  final _service = AgentClientService();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBottomSheet(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 24,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SectionTitle(
                        title: 'Clôturer la tontine',
                        subtitle:
                            'Action irréversible. Le solde sera transféré vers le compte principal avec application des pénalités.',
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => AnimatedBottomSheet.closeOf(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AgentClientListTile(client: widget.client),
                const SizedBox(height: 14),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57C00)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demandez au client de taper son code PIN secret pour valider cette clôture.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFE65100),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                ClientPinPad(
                  pinLength: 4,
                  isError: _errorMessage != null,
                  errorMessage: _errorMessage,
                  isLoading: _isSubmitting,
                  onPinEntered: _submitClose,
                ),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitClose(String pin) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    
    try {
      final updatedClient = await _service.closeTontine(
        clientId: widget.client.id,
        pinCode: pin,
      );
      if (!mounted) return;
      AnimatedBottomSheet.closeOf(context, updatedClient);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de clôturer la tontine.';
        _isSubmitting = false;
      });
    }
  }
}
