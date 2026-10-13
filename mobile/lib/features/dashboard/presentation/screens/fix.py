import sys
import os

file_path = r'c:\Users\HP\projects\finance\mobile\lib\features\dashboard\presentation\screens\tontine_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _StopTontineDialog constructor and state
content = content.replace(
'''class _StopTontineDialog extends StatefulWidget {
  final TontineCycle cycle;

  const _StopTontineDialog({
    required this.cycle,
  });''',
'''class _StopTontineDialog extends StatefulWidget {
  final TontineCycle cycle;
  final DashboardBloc dashboardBloc;

  const _StopTontineDialog({
    required this.cycle,
    required this.dashboardBloc,
  });''')

content = content.replace(
'''await context.read<DashboardBloc>().stopTontineEarlyAndWait();''',
'''await widget.dashboardBloc.stopTontineEarlyAndWait();''')

content = content.replace(
'''  void _showEarlyStopDialog(BuildContext context, TontineCycle cycle) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StopTontineDialog(
        cycle: cycle,
      ),
    );
  }''',
'''  void _showEarlyStopDialog(BuildContext context, TontineCycle cycle) async {
    final dashboardBloc = context.read<DashboardBloc>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StopTontineDialog(
        cycle: cycle,
        dashboardBloc: dashboardBloc,
      ),
    );
  }''')


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed Bloc issue")
