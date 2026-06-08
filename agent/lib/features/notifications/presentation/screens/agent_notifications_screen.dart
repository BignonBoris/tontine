import 'dart:async';

import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/services/realtime_notification_service.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/notifications/data/services/agent_notification_service.dart';
import 'package:agent/features/notifications/domain/entities/agent_notification_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AgentNotificationsScreen extends StatefulWidget {
  const AgentNotificationsScreen({super.key});

  @override
  State<AgentNotificationsScreen> createState() =>
      _AgentNotificationsScreenState();
}

class _AgentNotificationsScreenState extends State<AgentNotificationsScreen> {
  final _service = AgentNotificationService();
  final _realtimeService = RealtimeNotificationService();
  StreamSubscription<RealtimeNotificationEvent>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  bool _disposed = false;
  late Future<List<AgentNotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _service.fetchNotifications();
    _ensureRealtimeSubscription();
  }

  void _reload() {
    setState(() {
      _notificationsFuture = _service.fetchNotifications();
    });
  }

  void _ensureRealtimeSubscription() {
    if (_realtimeSubscription != null) {
      return;
    }

    _realtimeSubscription = _realtimeService.stream.listen((event) {
      if (_disposed) {
        return;
      }

      if (event.eventName == 'notification.created') {
        _scheduleRealtimeRefresh();
      }
    });
  }

  void _scheduleRealtimeRefresh() {
    if (_disposed) {
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(const Duration(milliseconds: 500), () {
      if (_disposed || !mounted) {
        return;
      }
      _reload();
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      await _service.markAllNotificationsAsRead();
      if (!mounted) {
        return;
      }
      _reload();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Toutes les notifications sont lues.')),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _service.markNotificationAsRead(notificationId);
      if (!mounted) {
        return;
      }
      _reload();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeRefreshTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_realtimeService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgentAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          FutureBuilder<List<AgentNotificationItem>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? const <AgentNotificationItem>[];
              final hasUnread = notifications.any((item) => !item.isRead);
              if (!hasUnread) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: _markAllAsRead,
                child: const Text('Tout lire'),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<AgentNotificationItem>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 420,
                    child: AgentLoadingView(
                      message: 'Chargement des notifications...',
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is ApiException
                  ? error.message
                  : 'Impossible de charger les notifications agent.';
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 420,
                    child: AgentErrorView(
                      title: 'Notifications indisponibles',
                      message: message,
                      onRetry: _reload,
                    ),
                  ),
                ],
              );
            }

            final notifications = snapshot.data ?? const <AgentNotificationItem>[];
            if (notifications.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 420,
                    child: AgentEmptyView(
                      icon: Icons.notifications_none_rounded,
                      title: 'Aucune notification',
                      message:
                          'Les alertes de caisse, de groupe et de retrait apparaitront ici.',
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: notification.isRead
                      ? null
                      : () => _markAsRead(notification.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AgentNotificationItem notification;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(notification.type);

    return SoftSectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(palette.icon, color: palette.foreground, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AgentAppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: AgentAppTheme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AgentAppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(notification.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AgentAppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  _NotificationPalette _paletteFor(AgentNotificationType type) {
    switch (type) {
      case AgentNotificationType.deposit:
        return const _NotificationPalette(
          background: Color(0xFFE7F5ED),
          foreground: Color(0xFF1E7A3A),
          icon: Icons.savings_outlined,
        );
      case AgentNotificationType.cycle:
        return const _NotificationPalette(
          background: Color(0xFFEAF1FF),
          foreground: Color(0xFF2E5BFF),
          icon: Icons.loop_rounded,
        );
      case AgentNotificationType.goal:
        return const _NotificationPalette(
          background: Color(0xFFFFF3E0),
          foreground: Color(0xFFB26A00),
          icon: Icons.flag_outlined,
        );
      case AgentNotificationType.marketplace:
        return const _NotificationPalette(
          background: Color(0xFFF3ECFF),
          foreground: Color(0xFF6E44FF),
          icon: Icons.shopping_bag_outlined,
        );
      case AgentNotificationType.system:
        return const _NotificationPalette(
          background: Color(0xFFE9EEF5),
          foreground: AgentAppTheme.primaryColor,
          icon: Icons.notifications_none_rounded,
        );
    }
  }
}

class _NotificationPalette {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _NotificationPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
