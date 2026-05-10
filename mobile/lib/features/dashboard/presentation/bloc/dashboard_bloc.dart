import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';

import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final RemoteDashboardService _remoteDashboardService;

  DashboardBloc({RemoteDashboardService? remoteDashboardService})
    : _remoteDashboardService =
          remoteDashboardService ?? RemoteDashboardService(),
      super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<AddGoal>(_onAddGoal);
    on<CloseGoal>(_onCloseGoal);
    on<AddFundsToGoal>(_onAddFundsToGoal);
    on<TransferToTontine>(_onTransferToTontine);
    on<ConfigureTontineStake>(_onConfigureTontineStake);
    on<MakeTontineDeposit>(_onMakeTontineDeposit);
    on<ConfirmTontineCyclePayout>(_onConfirmTontineCyclePayout);
    on<StopTontineEarly>(_onStopTontineEarly);
    on<BuyMarketplaceOfferNow>(_onBuyMarketplaceOfferNow);
    on<AdvanceMarketOrderStatus>(_onAdvanceMarketOrderStatus);
    on<CancelMarketOrder>(_onCancelMarketOrder);
    on<ToggleMarketplaceFavorite>(_onToggleMarketplaceFavorite);
    on<CreateGoalFromMarketplaceOffer>(_onCreateGoalFromMarketplaceOffer);
    on<SaveUserProfile>(_onSaveUserProfile);
    on<SaveProfilePreferences>(_onSaveProfilePreferences);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllNotificationsAsRead);
    on<TogglePriority>((event, emit) => _emitUnsupportedState(emit));
    on<TransferFunds>((event, emit) => _emitUnsupportedState(emit));
    on<ReorderGoalPriority>((event, emit) => _emitUnsupportedState(emit));
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final snapshot = await _remoteDashboardService.fetchDashboardSnapshot();
      emit(
        DashboardLoaded(
          goals: snapshot.goals,
          availableBalance: snapshot.availableBalance,
          tontineBalance: snapshot.tontineBalance,
          tontineCycle: snapshot.tontineCycle,
          tontineHistory: snapshot.tontineHistory,
          tontineArchives: snapshot.tontineArchives,
          availableBalanceHistory: snapshot.availableBalanceHistory,
          withdrawals: snapshot.withdrawals,
          marketOffers: snapshot.marketOffers,
          marketOrders: snapshot.marketOrders,
          notifications: snapshot.notifications,
          favoriteOfferIds: snapshot.favoriteOfferIds,
          profile: snapshot.profile,
          preferences: snapshot.preferences,
        ),
      );
    } on ApiException catch (error) {
      emit(_mapApiError(error));
    } catch (error) {
      emit(
        DashboardError(
          "Impossible de charger les donnees depuis le serveur. ${error.toString()}",
        ),
      );
    }
  }

  Future<void> _onAddGoal(AddGoal event, Emitter<DashboardState> emit) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.createGoal(event.goal),
    );
  }

  Future<void> _onCloseGoal(
    CloseGoal event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.closeGoal(event.goalId),
    );
  }

  Future<void> _onAddFundsToGoal(
    AddFundsToGoal event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.fundGoal(event.goalId, event.amount),
    );
  }

  Future<void> _onTransferToTontine(
    TransferToTontine event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.transferAvailableToTontine(event.amount),
    );
  }

  Future<void> _onConfigureTontineStake(
    ConfigureTontineStake event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.configureStake(event.stakeAmount),
    );
  }

  Future<void> _onMakeTontineDeposit(
    MakeTontineDeposit event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.makeTontineDeposit(event.amount),
    );
  }

  Future<void> _onConfirmTontineCyclePayout(
    ConfirmTontineCyclePayout event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(emit, _remoteDashboardService.confirmTontinePayout);
  }

  Future<void> _onStopTontineEarly(
    StopTontineEarly event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(emit, _remoteDashboardService.stopTontineEarly);
  }

  Future<void> _onBuyMarketplaceOfferNow(
    BuyMarketplaceOfferNow event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.buyMarketplaceOfferNow(
        event.offer,
        quantity: event.quantity,
      ),
    );
  }

  Future<void> _onAdvanceMarketOrderStatus(
    AdvanceMarketOrderStatus event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.advanceOrder(event.orderId),
    );
  }

  Future<void> _onCancelMarketOrder(
    CancelMarketOrder event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.cancelOrder(event.orderId),
    );
  }

  Future<void> _onToggleMarketplaceFavorite(
    ToggleMarketplaceFavorite event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.toggleFavorite(event.offerId),
    );
  }

  Future<void> _onCreateGoalFromMarketplaceOffer(
    CreateGoalFromMarketplaceOffer event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.createGoalFromMarketplaceOffer(
        event.offer,
        quantity: event.quantity,
      ),
    );
  }

  Future<void> _onSaveUserProfile(
    SaveUserProfile event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.saveUserProfile(event.profile),
    );
  }

  Future<void> _onSaveProfilePreferences(
    SaveProfilePreferences event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () => _remoteDashboardService.savePreferences(event.preferences),
    );
  }

  Future<void> _onMarkNotificationAsRead(
    MarkNotificationAsRead event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      () =>
          _remoteDashboardService.markNotificationAsRead(event.notificationId),
      reload: false,
    );
  }

  Future<void> _onMarkAllNotificationsAsRead(
    MarkAllNotificationsAsRead event,
    Emitter<DashboardState> emit,
  ) async {
    await _runMutation(
      emit,
      _remoteDashboardService.markAllNotificationsAsRead,
      reload: false,
    );
  }

  void _emitUnsupportedState(Emitter<DashboardState> emit) {
    final previousState = state;
    if (previousState is DashboardLoaded) {
      emit(DashboardError("Cette action n'est pas encore disponible."));
      emit(previousState);
    }
  }

  Future<void> _runMutation(
    Emitter<DashboardState> emit,
    Future<void> Function() action, {
    bool reload = true,
  }) async {
    try {
      await action();
      if (reload) {
        add(LoadDashboardData());
        return;
      }

      final snapshot = await _remoteDashboardService.fetchDashboardSnapshot();
      emit(
        DashboardLoaded(
          goals: snapshot.goals,
          availableBalance: snapshot.availableBalance,
          tontineBalance: snapshot.tontineBalance,
          tontineCycle: snapshot.tontineCycle,
          tontineHistory: snapshot.tontineHistory,
          tontineArchives: snapshot.tontineArchives,
          availableBalanceHistory: snapshot.availableBalanceHistory,
          withdrawals: snapshot.withdrawals,
          marketOffers: snapshot.marketOffers,
          marketOrders: snapshot.marketOrders,
          notifications: snapshot.notifications,
          favoriteOfferIds: snapshot.favoriteOfferIds,
          profile: snapshot.profile,
          preferences: snapshot.preferences,
        ),
      );
    } on ApiException catch (error) {
      emit(_mapApiError(error));
    } catch (error) {
      emit(
        DashboardError("Une erreur serveur est survenue. ${error.toString()}"),
      );
    }
  }

  DashboardError _mapApiError(ApiException error) {
    switch (error.type) {
      case ApiErrorType.sessionExpired:
        return DashboardError(
          error.message,
          title: "Session expiree",
          requiresReauthentication: true,
        );
      case ApiErrorType.network:
        return DashboardError(
          error.message,
          title: "Connexion indisponible",
        );
      case ApiErrorType.server:
        return DashboardError(
          error.message,
          title: "Serveur indisponible",
        );
      case ApiErrorType.validation:
        return DashboardError(
          error.message,
          title: "Action impossible",
        );
      case ApiErrorType.unauthorized:
        return DashboardError(
          error.message,
          title: "Acces refuse",
        );
      case ApiErrorType.unknown:
        return DashboardError(error.message);
    }
  }
}
