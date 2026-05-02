import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';

class DashboardLoadingView extends StatelessWidget {
  final String? label;
  final bool inline;

  const DashboardLoadingView({super.key, this.label, this.inline = false});

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(
              label!,
              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
            ),
          ],
        ],
      ),
    );

    if (inline) {
      return content;
    }

    return Scaffold(backgroundColor: const Color(0xFFF8F9FE), body: content);
  }
}

class DashboardErrorView extends StatelessWidget {
  final String message;
  final String title;
  final bool inline;
  final bool requiresReauthentication;

  const DashboardErrorView({
    super.key,
    required this.message,
    this.title = "Impossible de charger les donnees",
    this.inline = false,
    this.requiresReauthentication = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
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
                Icons.cloud_off_rounded,
                size: 34,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                if (requiresReauthentication) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/auth_choice',
                    (route) => false,
                  );
                  return;
                }

                context.read<DashboardBloc>().add(LoadDashboardData());
              },
              icon: Icon(
                requiresReauthentication
                    ? Icons.login_rounded
                    : Icons.refresh_rounded,
              ),
              label: Text(
                requiresReauthentication ? "Se reconnecter" : "Reessayer",
              ),
            ),
          ],
        ),
      ),
    );

    if (inline) {
      return content;
    }

    return Scaffold(backgroundColor: const Color(0xFFF8F9FE), body: content);
  }
}
