import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/domain/entities/app_notification_item.dart';

class AppNotificationListItem extends StatelessWidget {
  final AppNotificationItem notification;
  final VoidCallback? onTap;

  const AppNotificationListItem({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _paletteFor(notification.type);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE8ECF5)
                : AppTheme.primaryColor.withOpacity(0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(colors.icon, color: colors.foreground, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM, HH:mm', 'fr_FR').format(
                          notification.createdAt,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 10),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _NotificationPalette _paletteFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.deposit:
        return const _NotificationPalette(
          background: Color(0xFFE8F5E9),
          foreground: Color(0xFF2E7D32),
          icon: Icons.south_west_rounded,
        );
      case AppNotificationType.cycle:
        return const _NotificationPalette(
          background: Color(0xFFE8EEF9),
          foreground: AppTheme.primaryColor,
          icon: Icons.autorenew_rounded,
        );
      case AppNotificationType.goal:
        return const _NotificationPalette(
          background: Color(0xFFFFF4E5),
          foreground: Color(0xFF8A5B00),
          icon: Icons.flag_rounded,
        );
      case AppNotificationType.marketplace:
        return const _NotificationPalette(
          background: Color(0xFFEAF6F4),
          foreground: Color(0xFF107C67),
          icon: Icons.shopping_bag_outlined,
        );
      case AppNotificationType.system:
        return const _NotificationPalette(
          background: Color(0xFFF1F3F6),
          foreground: Color(0xFF5F6368),
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
