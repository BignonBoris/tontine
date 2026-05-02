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

class GoalsListScreen extends StatelessWidget {
  const GoalsListScreen({super.key});

  // Fonction de formatage locale si formatFCFA n'est pas exporté globalement
  String _format(num amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Mes Coffres",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
        actions: [
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              if (state is DashboardLoaded) {
                final closedCount = state.goals
                    .where((g) => g.status == GoalStatus.closed)
                    .length;
                return IconButton(
                  icon: Badge(
                    label: Text(closedCount.toString()),
                    isLabelVisible: closedCount > 0,
                    child: const Icon(
                      Icons.archive_outlined,
                      color: primaryBlue,
                    ),
                  ),
                  onPressed: () => _showClosedGoals(context, state.goals),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
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
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showAddGoalDialog(context, context.read<DashboardBloc>()),
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Nouveau Coffre",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // ... (garder les mêmes imports en haut du fichier)

  Widget _buildGoalItem(BuildContext context, TontineGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          // --- FIX ICI : On récupère l'instance du bloc actuelle ---
          final dashboardBloc = context.read<DashboardBloc>();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: dashboardBloc, // On transmet le bloc à la nouvelle page
                child: GoalDetailScreen(goalId: goal.id),
              ),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: goal.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(goal.icon, color: goal.color),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            // La jauge de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: goal.progress,
                backgroundColor: goal.color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        subtitle: Text(
          "${_format(goal.currentAmount)} F / ${_format(goal.targetAmount)} F",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${(goal.progress * 100).toInt()}%",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: goal.color,
                fontSize: 14,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Coffres Clôturés",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (closedGoals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text("Aucun coffre archivé"),
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
