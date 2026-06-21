import '../../domain/entities/app_notification_item.dart';
import '../../domain/entities/available_balance_history_entry.dart';
import '../../domain/entities/market_offer.dart';
import '../../domain/entities/market_order.dart';
import '../../domain/entities/profile_preferences.dart';
import '../../domain/entities/tontine_archive_entry.dart';
import '../../domain/entities/tontine_cycle.dart';
import '../../domain/entities/tontine_history_entry.dart';
import '../../domain/entities/tontine_goal.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/withdrawal_summary.dart';

abstract class DashboardState {}

enum DashboardStatusVariant { info, warning, error }

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<TontineGoal> goals;
  final double availableBalance;
  final double tontineBalance;
  final TontineCycle? tontineCycle;
  final List<TontineHistoryEntry> tontineHistory;
  final List<TontineArchiveEntry> tontineArchives;
  final List<AvailableBalanceHistoryEntry> availableBalanceHistory;
  final List<WithdrawalSummary> withdrawals;
  final List<MarketOffer> marketOffers;
  final List<MarketOrder> marketOrders;
  final List<AppNotificationItem> notifications;
  final List<String> favoriteOfferIds;
  final UserProfile profile;
  final ProfilePreferences preferences;
  final String? statusMessage;
  final DashboardStatusVariant statusVariant;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final bool isFromCache;

  DashboardLoaded({
    required this.goals,
    required this.availableBalance,
    required this.tontineBalance,
    required this.tontineCycle,
    required this.tontineHistory,
    required this.tontineArchives,
    required this.availableBalanceHistory,
    required this.withdrawals,
    required this.marketOffers,
    required this.marketOrders,
    required this.notifications,
    required this.favoriteOfferIds,
    required this.profile,
    required this.preferences,
    this.statusMessage,
    this.statusVariant = DashboardStatusVariant.info,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.isFromCache = false,
  });

  DashboardLoaded copyWith({
    List<TontineGoal>? goals,
    double? availableBalance,
    double? tontineBalance,
    TontineCycle? tontineCycle,
    List<TontineHistoryEntry>? tontineHistory,
    List<TontineArchiveEntry>? tontineArchives,
    List<AvailableBalanceHistoryEntry>? availableBalanceHistory,
    List<WithdrawalSummary>? withdrawals,
    List<MarketOffer>? marketOffers,
    List<MarketOrder>? marketOrders,
    List<AppNotificationItem>? notifications,
    List<String>? favoriteOfferIds,
    UserProfile? profile,
    ProfilePreferences? preferences,
    String? statusMessage,
    DashboardStatusVariant? statusVariant,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    bool? isFromCache,
  }) {
    return DashboardLoaded(
      goals: goals ?? this.goals,
      availableBalance: availableBalance ?? this.availableBalance,
      tontineBalance: tontineBalance ?? this.tontineBalance,
      tontineCycle: tontineCycle ?? this.tontineCycle,
      tontineHistory: tontineHistory ?? this.tontineHistory,
      tontineArchives: tontineArchives ?? this.tontineArchives,
      availableBalanceHistory:
          availableBalanceHistory ?? this.availableBalanceHistory,
      withdrawals: withdrawals ?? this.withdrawals,
      marketOffers: marketOffers ?? this.marketOffers,
      marketOrders: marketOrders ?? this.marketOrders,
      notifications: notifications ?? this.notifications,
      favoriteOfferIds: favoriteOfferIds ?? this.favoriteOfferIds,
      profile: profile ?? this.profile,
      preferences: preferences ?? this.preferences,
      statusMessage: statusMessage ?? this.statusMessage,
      statusVariant: statusVariant ?? this.statusVariant,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

class DashboardOffline extends DashboardState {
  final String title;
  final String message;

  DashboardOffline({
    this.title = "Mode hors ligne",
    required this.message,
  });
}

class DashboardError extends DashboardState {
  final String title;
  final String message;
  final bool requiresReauthentication;

  DashboardError(
    this.message, {
    this.title = "Impossible de charger les donnees",
    this.requiresReauthentication = false,
  });
}
