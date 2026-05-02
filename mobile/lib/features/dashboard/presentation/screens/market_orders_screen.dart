import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/domain/entities/market_order.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/market_order_detail_sheet.dart';
import 'package:mobile/features/dashboard/presentation/widgets/market_order_list_tile.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';

class MarketOrdersScreen extends StatelessWidget {
  const MarketOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          "Mes commandes",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
              label: "Chargement des commandes...",
              inline: true,
            );
          }

          if (state.marketOrders.isEmpty) {
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
                        Icons.shopping_bag_outlined,
                        size: 34,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Aucune commande",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Vos achats marketplace apparaitront ici avec leur statut.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: state.marketOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = state.marketOrders[index];
              return MarketOrderListTile(
                order: order,
                onTap: () => _showOrderDetails(context, order),
              );
            },
          );
        },
      ),
    );
  }

  void _showOrderDetails(BuildContext context, MarketOrder order) {
    final bloc = context.read<DashboardBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MarketOrderDetailSheet(
        order: order,
        onAdvance: order.status.canAdvance
            ? () {
                bloc.add(AdvanceMarketOrderStatus(order.id));
                Navigator.pop(sheetContext);
              }
            : null,
        onCancel: order.status.canCancel
            ? () {
                bloc.add(CancelMarketOrder(order.id));
                Navigator.pop(sheetContext);
              }
            : null,
      ),
    );
  }
}
