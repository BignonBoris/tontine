import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/add_goal_dialog.dart';
import '../widgets/dashboard_state_views.dart';
import 'goal_detail_screen.dart';

import 'package:mobile/core/theme/app_theme.dart';
import '../widgets/finance_hero_header.dart';

class GoalsListScreen extends StatelessWidget {
  const GoalsListScreen({super.key});

  // Fonction de formatage locale si formatFCFA n'est pas exportÃ© globalement
  String _format(num amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final closedCount = state is DashboardLoaded
            ? state.goals.where((g) => g.status == GoalStatus.closed).length
            : 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          body: Column(
            children: [
              FinanceHeroHeader(
                title: "Mes Coffres",
                subtitle: "Épargne projet & objectifs bloqués",
                showBackButton: false,
                actions: [
                  FinanceHeaderActionButton(
                    icon: Icons.archive_outlined,
                    badgeCount: closedCount,
                    onTap: () {
                      if (state is DashboardLoaded) {
                        _showClosedGoals(context, state.goals);
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: _buildGoalsContent(context, state),
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(context, state),
        );
      },
    );
  }

  Widget _buildGoalsContent(BuildContext context, DashboardState state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardOffline) {
            return DashboardOfflineView(
              title: state.title,
              message: state.message,
              inline: true,
            );
          }

          if (state is DashboardError) {
            return DashboardErrorView(
              title: state.title,
              message: state.message,
              inline: true,
              requiresReauthentication: state.requiresReauthentication,
            );
          }

          if (state is DashboardLoaded) {
            final activeGoals = state.goals
                .where((g) => g.status == GoalStatus.active)
                .toList();

            if (activeGoals.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: activeGoals.length,
              itemBuilder: (context, index) {
                final goal = activeGoals[index];
                return _buildGoalItem(context, goal);
              },
            );
          }
    return const DashboardLoadingView(
      label: "Chargement de vos coffres...",
      inline: true,
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, DashboardState state) {
    if (state is! DashboardLoaded) {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: () =>
          showAddGoalDialog(context, context.read<DashboardBloc>()),
      backgroundColor: AppTheme.primaryColor,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        "Nouveau Coffre",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ... (garder les mÃªmes imports en haut du fichier)

  Widget _buildGoalItem(BuildContext context, TontineGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: goal.color.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            final dashboardBloc = context.read<DashboardBloc>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider.value(
                  value: dashboardBloc,
                  child: GoalDetailScreen(goalId: goal.id),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: goal.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(goal.icon, color: goal.color, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Echeance dans ${goal.remainingDays}j",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: goal.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${(goal.progress * 100).toInt()}%",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: goal.color,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: goal.progress),
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: goal.color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Solde",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        Text(
                          "${_format(goal.currentAmount)} F",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Objectif",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        Text(
                          "${_format(goal.targetAmount)} F",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: goal.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (le reste du fichier reste identique)

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun coffre actif",
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showClosedGoals(BuildContext context, List<TontineGoal> goals) {
    final closedGoals = goals
        .where((g) => g.status == GoalStatus.closed)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Coffres Clôturés",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (closedGoals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 60,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Aucun coffre archivé",
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: closedGoals.length,
                  itemBuilder: (context, index) {
                    final goal = closedGoals[index];
                    return ListTile(
                      leading: Icon(goal.icon, color: Colors.grey),
                      title: Text(goal.title),
                      trailing: Text("${_format(goal.currentAmount)} F"),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
