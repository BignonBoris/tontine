import sys
import os

file_path = r'c:\Users\HP\projects\finance\mobile\lib\features\dashboard\presentation\screens\tontine_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace _showEarlyStopDialog
start_marker = '  void _showEarlyStopDialog(BuildContext context, TontineCycle cycle) {'
end_marker = '  void _showArchiveSummary(BuildContext context, TontineArchiveEntry archive) {'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

new_dialog_method = '''  void _showEarlyStopDialog(BuildContext context, TontineCycle cycle) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StopTontineDialog(
        cycle: cycle,
      ),
    );
  }

'''

content = content[:start_idx] + new_dialog_method + content[end_idx:]

# 2. Append _StopTontineDialog at the end of the file (before the last }? Wait, it's outside of any class, so just at the end of file)
new_classes = '''
enum _StopTontineStep { summary, pin, done }

class _StopTontineDialog extends StatefulWidget {
  final TontineCycle cycle;

  const _StopTontineDialog({
    required this.cycle,
  });

  @override
  State<_StopTontineDialog> createState() => _StopTontineDialogState();
}

class _StopTontineDialogState extends State<_StopTontineDialog>
    with SingleTickerProviderStateMixin {
  _StopTontineStep _step = _StopTontineStep.summary;
  String _pin = '';
  bool _isSubmitting = false;
  bool _isPinError = false;
  String? _apiError;
  bool _isAccepted = false; // For the checkbox

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  double get _netAmount => (widget.cycle.cumulativeAmount - widget.cycle.commissionAmount).clamp(
        0.0,
        double.infinity,
      );

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
      await context.read<DashboardBloc>().stopTontineEarlyAndWait();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _step = _StopTontineStep.done;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _apiError = error.message;
        _step = _StopTontineStep.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _apiError = 'La clôture de la tontine a échoué. Réessayez.';
        _step = _StopTontineStep.done;
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
      canPop: _step != _StopTontineStep.pin || !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _StopTontineStep.pin && !_isSubmitting) {
          setState(() {
            _step = _StopTontineStep.summary;
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
              _StopTontineStep.summary => _buildSummaryStep(),
              _StopTontineStep.pin     => _buildPinStep(),
              _StopTontineStep.done    => _buildDoneStep(),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stop_circle_outlined,
                color: AppTheme.errorColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Arrêter la tontine ?",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Cette action interrompt immédiatement votre cycle de 31 jours. Conformément aux règles de la tontine, une mise est retenue en pénalité de rupture.",
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppTheme.textSecondaryColor,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TontineSummaryRow(
                label: "Cumul actuel cotisé",
                value: " F CFA",
              ),
              const SizedBox(height: 6),
              _TontineSummaryRow(
                label: "Pénalité retenue (1 mise)",
                value: "-  F CFA",
                valueColor: AppTheme.errorColor,
              ),
              Divider(
                height: 16,
                color: AppTheme.primaryColor.withOpacity(0.10),
              ),
              _TontineSummaryRow(
                label: "Net reversé sur solde",
                value: " F CFA",
                bold: true,
                valueColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () {
            setState(() {
              _isAccepted = !_isAccepted;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _isAccepted,
                    activeColor: AppTheme.errorColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _isAccepted = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "J'ai bien compris que cet arrêt est irréversible et j'accepte la retenue de  F.",
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Annuler',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  disabledBackgroundColor:
                      AppTheme.errorColor.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isAccepted ? () => setState(() => _step = _StopTontineStep.pin) : null,
                child: Text('Confirmer',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: Colors.white)),
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
                        _step = _StopTontineStep.summary;
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
          'Entrez votre code PIN pour confirmer l\\'arrêt.',
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
              const CircularProgressIndicator(color: AppTheme.errorColor),
              const SizedBox(height: 10),
              Text('Arrêt en cours...',
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
          isError ? 'Échec de l\\'arrêt' : 'Tontine arrêtée !',
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isError ? AppTheme.errorColor : AppTheme.successColor),
        ),
        const SizedBox(height: 10),
        Text(
          isError
              ? _apiError!
              : ' F ont été reversés\\nsur votre solde disponible.',
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(isError ? 'Fermer' : 'Parfait !',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// Ligne de résumé label / valeur pour tontine
class _TontineSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _TontineSummaryRow({
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
                fontSize: 12, color: AppTheme.textSecondaryColor)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimaryColor)),
      ],
    );
  }
}
'''

content = content + new_classes

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
