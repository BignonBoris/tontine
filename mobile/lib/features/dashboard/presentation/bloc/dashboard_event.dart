import '../../domain/entities/market_offer.dart';
import '../../domain/entities/profile_preferences.dart';
import '../../domain/entities/tontine_goal.dart';
import '../../domain/entities/user_profile.dart';

abstract class DashboardEvent {}

class LoadDashboardData extends DashboardEvent {}

class AddGoal extends DashboardEvent {
  final TontineGoal goal;
  AddGoal(this.goal);
}

class MakeDeposit extends DashboardEvent {
  final String goalId;
  final double amount;
  MakeDeposit({required this.goalId, required this.amount});
}

class TogglePriority extends DashboardEvent {
  final String goalId;
  TogglePriority(this.goalId);
}

class CloseGoal extends DashboardEvent {
  final String goalId;
  CloseGoal(this.goalId);
}

class TransferFunds extends DashboardEvent {
  final String fromGoalId;
  final String toGoalId;
  final double amount;

  TransferFunds({
    required this.fromGoalId,
    required this.toGoalId,
    required this.amount,
  });
}

class ReorderGoalPriority extends DashboardEvent {
  final String goalId;
  final String? targetGoalId;
  ReorderGoalPriority({required this.goalId, this.targetGoalId});
}

class AddFundsToGoal extends DashboardEvent {
  final String goalId;
  final double amount;

  AddFundsToGoal(this.goalId, this.amount);
}

class TransferToTontine extends DashboardEvent {
  final double amount;

  TransferToTontine(this.amount);
}

class ConfigureTontineStake extends DashboardEvent {
  final double stakeAmount;

  ConfigureTontineStake(this.stakeAmount);
}

class MakeTontineDeposit extends DashboardEvent {
  final double amount;

  MakeTontineDeposit(this.amount);
}

class ConfirmTontineCyclePayout extends DashboardEvent {}

class StopTontineEarly extends DashboardEvent {}

class BuyMarketplaceOfferNow extends DashboardEvent {
  final MarketOffer offer;
  final int quantity;

  BuyMarketplaceOfferNow(this.offer, {this.quantity = 1});
}

class AdvanceMarketOrderStatus extends DashboardEvent {
  final String orderId;

  AdvanceMarketOrderStatus(this.orderId);
}

class CancelMarketOrder extends DashboardEvent {
  final String orderId;

  CancelMarketOrder(this.orderId);
}

class ToggleMarketplaceFavorite extends DashboardEvent {
  final String offerId;

  ToggleMarketplaceFavorite(this.offerId);
}

class CreateGoalFromMarketplaceOffer extends DashboardEvent {
  final MarketOffer offer;
  final int quantity;

  CreateGoalFromMarketplaceOffer(this.offer, {this.quantity = 1});
}

class SaveUserProfile extends DashboardEvent {
  final UserProfile profile;

  SaveUserProfile(this.profile);
}

class SaveProfilePreferences extends DashboardEvent {
  final ProfilePreferences preferences;

  SaveProfilePreferences(this.preferences);
}

class MarkNotificationAsRead extends DashboardEvent {
  final String notificationId;

  MarkNotificationAsRead(this.notificationId);
}

class MarkAllNotificationsAsRead extends DashboardEvent {}
