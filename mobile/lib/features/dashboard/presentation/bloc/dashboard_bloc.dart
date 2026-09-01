import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/realtime_notification_service.dart';
import 'package:mobile/features/dashboard/data/services/dashboard_cache_service.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';

import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final RemoteDashboardService _remoteDashboardService;
  final DashboardCacheService _dashboardCacheService;
  final RealtimeNotificationService _realtimeNotificationService;
  StreamSubscription<RealtimeNotificationEvent>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;

  DashboardBloc({RemoteDashboardService? remoteDashboardService})
    : _remoteDashboardService =
          remoteDashboardService ?? RemoteDashboardService(),
      _dashboardCacheService = DashboardCacheService(),
      _realtimeNotificationService = RealtimeNotificationService(),
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
    _ensureRealtimeSubscription();
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    CachedDashboardSnapshot? cachedSnapshot;
    try {
      cachedSnapshot = await _dashboardCacheService.loadSnapshot();
    } catch (_) {
      cachedSnapshot = null;
    }

    if (cachedSnapshot != null) {
      emit(
        _buildLoadedState(
          cachedSnapshot.snapshot,
          lastSyncedAt: cachedSnapshot.lastSyncedAt,
          isFromCache: true,
          isSyncing: true,
          statusMessage: "Synchronisation en cours...",
          statusVariant: DashboardStatusVariant.info,
        ),
      );
    } else {
      emit(DashboardLoading());
    }

    try {
      final snapshot = await _remoteDashboardService.fetchDashboardSnapshot();
      final lastSyncedAt = DateTime.now();
      await _dashboardCacheService.saveSnapshot(
        snapshot,
        lastSyncedAt: lastSyncedAt,
      );
      emit(
        _buildLoadedState(
          snapshot,
          lastSyncedAt: lastSyncedAt,
        ),
      );
      _ensureRealtimeSubscription();
    } on ApiException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[DASHBOARD] load failed => type=${error.type} status=${error.statusCode} message=${error.message}',
        );
      }
      if (error.type == ApiErrorType.sessionExpired ||
          error.type == ApiErrorType.unauthorized) {
        emit(_mapApiError(error));
        return;
      }

      if (cachedSnapshot != null) {
        emit(
          _buildLoadedState(
            cachedSnapshot.snapshot,
            lastSyncedAt: cachedSnapshot.lastSyncedAt,
            isFromCache: true,
            isSyncing: false,
            statusMessage: _syncStatusMessage(error),
            statusVariant: _syncStatusVariant(error),
          ),
        );
        return;
      }

      emit(
        DashboardOffline(
          title: _offlineTitleFor(error),
          message: _offlineMessageFor(error),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DASHBOARD] load unexpected error => ${error.toString()}');
      }
      if (cachedSnapshot != null) {
        emit(
          _buildLoadedState(
            cachedSnapshot.snapshot,
            lastSyncedAt: cachedSnapshot.lastSyncedAt,
            isFromCache: true,
            isSyncing: false,
            statusMessage:
                "Synchronisation impossible pour le moment. Les donnees locales restent visibles.",
            statusVariant: DashboardStatusVariant.warning,
          ),
        );
        return;
      }

      emit(
        DashboardOffline(
          title: "Connexion indisponible",
          message:
              "Impossible de charger votre espace. Verifiez votre connexion puis reessayez.",
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
      () => _remoteDashboardService.configureStake(event.stakeAmount, termsAccepted: event.termsAccepted),
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

  void _ensureRealtimeSubscription() {
    if (_realtimeSubscription != null) {
      return;
    }

    _realtimeSubscription = _realtimeNotificationService.stream.listen(
      (event) {
        if (event.eventName == 'notification.created') {
          _scheduleRealtimeRefresh();
        }
      },
    );
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        if (!isClosed) {
          add(LoadDashboardData());
        }
      },
    );
  }

  DashboardLoaded _buildLoadedState(
    RemoteDashboardSnapshot snapshot, {
    DateTime? lastSyncedAt,
    bool isFromCache = false,
    bool isSyncing = false,
    String? statusMessage,
    DashboardStatusVariant statusVariant = DashboardStatusVariant.info,
  }) {
    return DashboardLoaded(
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
      lastSyncedAt: lastSyncedAt,
      isFromCache: isFromCache,
      isSyncing: isSyncing,
      statusMessage: statusMessage,
      statusVariant: statusVariant,
    );
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
      final lastSyncedAt = DateTime.now();
      await _dashboardCacheService.saveSnapshot(
        snapshot,
        lastSyncedAt: lastSyncedAt,
      );
      emit(
        _buildLoadedState(
          snapshot,
          lastSyncedAt: lastSyncedAt,
        ),
      );
      _ensureRealtimeSubscription();
    } on ApiException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[DASHBOARD] mutation failed => type=${error.type} status=${error.statusCode} message=${error.message}',
        );
      }
      if (error.type == ApiErrorType.sessionExpired ||
          error.type == ApiErrorType.unauthorized) {
        emit(_mapApiError(error));
        return;
      }

      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            isSyncing: false,
            statusMessage: _mutationStatusMessage(error),
            statusVariant: _mutationStatusVariant(error),
          ),
        );
        return;
      }

      emit(_mapApiError(error));
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[DASHBOARD] mutation unexpected error => ${error.toString()}',
        );
      }
      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            isSyncing: false,
            statusMessage:
                "L'action a echoue. Les donnees locales restent disponibles.",
            statusVariant: DashboardStatusVariant.warning,
          ),
        );
        return;
      }

      emit(DashboardError("Une erreur serveur est survenue. ${error.toString()}"));
    }
  }

  @override
  Future<void> close() async {
    _realtimeRefreshTimer?.cancel();
    await _realtimeSubscription?.cancel();
    await _realtimeNotificationService.dispose();
    return super.close();
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

  String _offlineTitleFor(ApiException error) {
    return switch (error.type) {
      ApiErrorType.network => "Connexion indisponible",
      ApiErrorType.server => "Serveur indisponible",
      ApiErrorType.validation => "Action impossible",
      ApiErrorType.sessionExpired => "Session expiree",
      ApiErrorType.unauthorized => "Acces refuse",
      ApiErrorType.unknown => "Synchronisation indisponible",
    };
  }

  String _offlineMessageFor(ApiException error) {
    return switch (error.type) {
      ApiErrorType.network =>
        "Aucune donnee locale n'est disponible pour le moment. Connectez-vous a internet puis reessayez.",
      ApiErrorType.server =>
        "Le serveur ne repond pas. Connectez-vous a nouveau pour charger votre espace.",
      ApiErrorType.validation =>
        error.message.isEmpty ? "Requete invalide." : error.message,
      ApiErrorType.sessionExpired =>
        "Votre session a expire. Reconnectez-vous pour continuer.",
      ApiErrorType.unauthorized =>
        error.message.isEmpty ? "Acces refuse." : error.message,
      ApiErrorType.unknown =>
        "Impossible de charger votre espace pour le moment. Reessayez plus tard.",
    };
  }

  String _syncStatusMessage(ApiException error) {
    return switch (error.type) {
      ApiErrorType.network =>
        "Mode hors ligne. Les donnees affichees proviennent du dernier chargement reussi.",
      ApiErrorType.server =>
        "Serveur indisponible. Les donnees locales restent visibles.",
      ApiErrorType.validation =>
        error.message.isEmpty ? "Action refusee." : error.message,
      ApiErrorType.sessionExpired =>
        "Session expiree. Reconnectez-vous pour continuer.",
      ApiErrorType.unauthorized =>
        error.message.isEmpty ? "Acces refuse." : error.message,
      ApiErrorType.unknown =>
        "Synchronisation indisponible. Les donnees locales restent visibles.",
    };
  }

  DashboardStatusVariant _syncStatusVariant(ApiException error) {
    return switch (error.type) {
      ApiErrorType.network => DashboardStatusVariant.warning,
      ApiErrorType.server => DashboardStatusVariant.warning,
      ApiErrorType.validation => DashboardStatusVariant.error,
      ApiErrorType.sessionExpired => DashboardStatusVariant.error,
      ApiErrorType.unauthorized => DashboardStatusVariant.error,
      ApiErrorType.unknown => DashboardStatusVariant.warning,
    };
  }

  String _mutationStatusMessage(ApiException error) {
    return switch (error.type) {
      ApiErrorType.network =>
        "Action impossible hors ligne. La modification n'a pas ete envoyee.",
      ApiErrorType.server =>
        "Serveur indisponible. La modification a ete interrompue.",
      ApiErrorType.validation =>
        error.message.isEmpty ? "Action invalide." : error.message,
      ApiErrorType.sessionExpired =>
        "Votre session a expire. Reconnectez-vous pour continuer.",
      ApiErrorType.unauthorized =>
        error.message.isEmpty ? "Acces refuse." : error.message,
      ApiErrorType.unknown =>
        "Action interrompue. Les donnees locales restent visibles.",
    };
  }

  DashboardStatusVariant _mutationStatusVariant(ApiException error) {
    return switch (error.type) {
      ApiErrorType.network => DashboardStatusVariant.warning,
      ApiErrorType.server => DashboardStatusVariant.warning,
      ApiErrorType.validation => DashboardStatusVariant.error,
      ApiErrorType.sessionExpired => DashboardStatusVariant.error,
      ApiErrorType.unauthorized => DashboardStatusVariant.error,
      ApiErrorType.unknown => DashboardStatusVariant.warning,
    };
  }
}
