import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/app_notification_list_item.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              if (state is DashboardError) {
                return const SizedBox.shrink();
              }

              if (state is! DashboardLoaded || state.notifications.isEmpty) {
                return const SizedBox.shrink();
              }

              final hasUnread = state.notifications.any((item) => !item.isRead);
              if (!hasUnread) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: () {
                  context.read<DashboardBloc>().add(
                    MarkAllNotificationsAsRead(),
                  );
                },
                child: const Text("Tout lire"),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardError) {
            return DashboardErrorView(
              title: state.title,
              message: state.message,
              inline: true,
              requiresReauthentication: state.requiresReauthentication,
            );
          }

          if (state is! DashboardLoaded) {
            return const DashboardLoadingView(
              label: "Chargement des notifications...",
              inline: true,
            );
          }

          if (state.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 34,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Aucune notification",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Les alertes de tontine, de coffres et de marketplace apparaitront ici.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            itemCount: state.notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = state.notifications[index];
              return AppNotificationListItem(
                notification: notification,
                onTap: () {
                  if (!notification.isRead) {
                    context.read<DashboardBloc>().add(
                      MarkNotificationAsRead(notification.id),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
