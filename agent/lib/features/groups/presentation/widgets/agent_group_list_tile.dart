import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/features/groups/domain/entities/agent_group.dart';
import 'package:flutter/material.dart';

class AgentGroupListTile extends StatelessWidget {
  final AgentGroup group;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AgentGroupListTile({
    super.key,
    required this.group,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scheduleStyle = _buildScheduleStyle();

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.10),
          foregroundColor: scheme.primary,
          child: const Icon(Icons.groups_2_outlined),
        ),
        title: Text(
          group.name,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricItem(
                  icon: Icons.group_outlined,
                  label: '${group.memberCount}/${group.participantCount}',
                ),
                _MetricItem(
                  icon: Icons.event_repeat_rounded,
                  label:
                      '${group.turnIntervalValue} ${_unitLabel(group.turnIntervalUnit)}',
                ),
                _MetricItem(
                  icon: Icons.payments_outlined,
                  label: '${group.contributionAmount.toStringAsFixed(0)} F',
                ),
                _MetricItem(
                  icon: Icons.percent_rounded,
                  label: group.commissionAmount > 0
                      ? formatFcfa(group.commissionAmount)
                      : 'Aucune',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: scheduleStyle.color,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(group.plannedStartDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheduleStyle.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if ((group.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                group.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: trailing,
      ),
    );
  }

  _ScheduleStyle _buildScheduleStyle() {
    final plannedDate = group.plannedStartDate;
    if (plannedDate == null) {
      return const _ScheduleStyle(
        color: Color(0xFF667085),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      plannedDate.year,
      plannedDate.month,
      plannedDate.day,
    );

    if (startDate.isBefore(today)) {
      return const _ScheduleStyle(
        color: Color(0xFFB42318),
      );
    }

    return const _ScheduleStyle(
      color: Color(0xFF067647),
    );
  }

  String _unitLabel(String value) {
    switch (value) {
      case 'day':
        return 'jour(s)';
      case 'week':
        return 'semaine(s)';
      case 'month':
      default:
        return 'mois';
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Non definie';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ScheduleStyle {
  final Color color;

  const _ScheduleStyle({
    required this.color,
  });
}
