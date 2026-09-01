import 'package:mobile/core/network/api_client.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile/features/dashboard/domain/entities/app_notification_item.dart';
import 'package:mobile/features/dashboard/domain/entities/available_balance_history_entry.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';
import 'package:mobile/features/dashboard/domain/entities/market_order.dart';
import 'package:mobile/features/dashboard/domain/entities/profile_preferences.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_archive_entry.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_history_entry.dart';
import 'package:mobile/features/dashboard/domain/entities/payment_method_option.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_transaction.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:mobile/features/dashboard/domain/entities/withdrawal_request_result.dart';
import 'package:mobile/features/dashboard/domain/entities/withdrawal_summary.dart';

class RemoteDashboardSnapshot {
  final List<TontineGoal> goals;
  final double availableBalance;
  final double tontineBalance;
  final TontineCycle? tontineCycle;
  final List<TontineHistoryEntry> tontineHistory;
  final List<TontineArchiveEntry> tontineArchives;
  final List<AvailableBalanceHistoryEntry> availableBalanceHistory;
  final List<WithdrawalSummary> withdrawals;
  final List<MarketOrder> marketOrders;
  final List<AppNotificationItem> notifications;
  final List<String> favoriteOfferIds;
  final List<MarketOffer> marketOffers;
  final UserProfile profile;
  final ProfilePreferences preferences;

  const RemoteDashboardSnapshot({
    required this.goals,
    required this.availableBalance,
    required this.tontineBalance,
    required this.tontineCycle,
    required this.tontineHistory,
    required this.tontineArchives,
    required this.availableBalanceHistory,
    required this.withdrawals,
    required this.marketOrders,
    required this.notifications,
    required this.favoriteOfferIds,
    required this.marketOffers,
    required this.profile,
    required this.preferences,
  });

  factory RemoteDashboardSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return RemoteDashboardSnapshot(
      goals: _asList(map['goals'])
          .map((entry) => TontineGoal.fromMap(_asMap(entry)))
          .toList(),
      availableBalance: _toDouble(map['availableBalance']),
      tontineBalance: _toDouble(map['tontineBalance']),
      tontineCycle: map['tontineCycle'] == null
          ? null
          : TontineCycle.fromMap(_asMap(map['tontineCycle'])),
      tontineHistory: _asList(map['tontineHistory'])
          .map((entry) => TontineHistoryEntry.fromMap(_asMap(entry)))
          .toList(),
      tontineArchives: _asList(map['tontineArchives'])
          .map((entry) => TontineArchiveEntry.fromMap(_asMap(entry)))
          .toList(),
      availableBalanceHistory: _asList(map['availableBalanceHistory'])
          .map((entry) => AvailableBalanceHistoryEntry.fromMap(_asMap(entry)))
          .toList(),
      withdrawals: _asList(map['withdrawals'])
          .map((entry) => WithdrawalSummary.fromMap(_asMap(entry)))
          .toList(),
      marketOrders: _asList(map['marketOrders'])
          .map((entry) => MarketOrder.fromMap(_asMap(entry)))
          .toList(),
      notifications: _asList(map['notifications'])
          .map((entry) => AppNotificationItem.fromMap(_asMap(entry)))
          .toList(),
      favoriteOfferIds: _asList(map['favoriteOfferIds'])
          .map((entry) => entry.toString())
          .where((value) => value.isNotEmpty)
          .toList(),
      marketOffers: _asList(map['marketOffers'])
          .map((entry) => MarketOffer.fromMap(_asMap(entry)))
          .toList(),
      profile: UserProfile.fromMap(_asMap(map['profile'])),
      preferences: ProfilePreferences.fromMap(_asMap(map['preferences'])),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goals': goals.map((goal) => goal.toMap()).toList(),
      'availableBalance': availableBalance,
      'tontineBalance': tontineBalance,
      'tontineCycle': tontineCycle?.toMap(),
      'tontineHistory': tontineHistory.map((entry) => entry.toMap()).toList(),
      'tontineArchives': tontineArchives.map((entry) => entry.toMap()).toList(),
      'availableBalanceHistory':
          availableBalanceHistory.map((entry) => entry.toMap()).toList(),
      'withdrawals': withdrawals.map((entry) => entry.toMap()).toList(),
      'marketOrders': marketOrders.map((entry) => entry.toMap()).toList(),
      'notifications': notifications.map((entry) => entry.toMap()).toList(),
      'favoriteOfferIds': favoriteOfferIds,
      'marketOffers': marketOffers.map((entry) => entry.toMap()).toList(),
      'profile': profile.toMap(),
      'preferences': preferences.toMap(),
    };
  }

  static Map<dynamic, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return <dynamic, dynamic>{};
  }

  static List<dynamic> _asList(dynamic raw) {
    if (raw is List) {
      return List<dynamic>.from(raw);
    }
    return <dynamic>[];
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

class RemoteDashboardService {
  final ApiClient _apiClient;
  final ApiClient _backgroundApiClient;

  RemoteDashboardService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _backgroundApiClient = ApiClient(
        invalidateSessionOnUnauthorized: false,
      );

  Future<RemoteDashboardSnapshot> fetchDashboardSnapshot() async {
    final goalsPayload = _asList(await _apiClient.get('/goals'));
    final walletPayload = _asMap(await _apiClient.get('/wallet'));
    final tontinePayload = _asMap(await _apiClient.get('/tontine'));
    final profilePayload = _asMap(await _apiClient.get('/profile'));

    final withdrawalsPayload = _asList(
      await _safeGet('/withdrawals', fallback: const <dynamic>[]),
    );
    final ordersPayload = _asList(
      await _safeGet('/marketplace/orders', fallback: const <dynamic>[]),
    );
    final notificationsPayload = _asList(
      await _safeGet('/notifications', fallback: const <dynamic>[]),
    );
    final favoritesPayload = _asList(
      await _safeGet('/marketplace/favorites', fallback: const <dynamic>[]),
    );
    final offersPayload = _asList(
      await _safeGet('/marketplace/offers', fallback: const <dynamic>[]),
    );

    final wallet = _asMap(walletPayload['wallet']);
    final walletHistory = _asList(walletPayload['history']);
    final cyclePayload = tontinePayload['cycle'];
    final cycleMap = cyclePayload is Map ? _asMap(cyclePayload) : null;
    final historyPayload = _asList(tontinePayload['history']);
    final archivesPayload = _asList(tontinePayload['archives']);
    final profilePreferences = _asMap(profilePayload['preferences']);

    final marketOffers = offersPayload
        .map((entry) => MarketOffer.fromMap(_asMap(entry)))
        .toList();

    return RemoteDashboardSnapshot(
      goals: goalsPayload.map(_goalFromApi).toList(),
      availableBalance: _toDouble(wallet['availableBalance']),
      tontineBalance: _toDouble(wallet['tontineBalance']),
      tontineCycle: cycleMap == null ? null : _cycleFromApi(cycleMap),
      tontineHistory: historyPayload.map(_historyFromApi).toList(),
      tontineArchives: archivesPayload.map(_archiveFromApi).toList(),
      availableBalanceHistory: walletHistory
          .map(_walletHistoryFromApi)
          .toList(),
      withdrawals: withdrawalsPayload.map(_withdrawalFromApi).toList(),
      marketOrders: ordersPayload.map(_marketOrderFromApi).toList(),
      notifications: notificationsPayload.map(_notificationFromApi).toList(),
      favoriteOfferIds: favoritesPayload
          .map((entry) => _asMap(entry)['id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(),
      marketOffers: marketOffers,
      profile: _profileFromApi(profilePayload),
      preferences: _preferencesFromApi(profilePreferences),
    );
  }

  Future<dynamic> _safeGet(
    String path, {
    required dynamic fallback,
  }) async {
    try {
      return await _backgroundApiClient.get(path);
    } on ApiException catch (error) {
      if (error.type == ApiErrorType.network ||
          error.type == ApiErrorType.server ||
          error.type == ApiErrorType.unknown ||
          error.type == ApiErrorType.sessionExpired ||
          error.type == ApiErrorType.unauthorized) {
        return fallback;
      }
      return fallback;
    }
  }

  Future<void> configureStake(double stakeAmount, {required bool termsAccepted}) {
    return _apiClient.post(
      '/tontine/configure',
      body: {
        'stakeAmount': stakeAmount,
        'termsAccepted': termsAccepted,
      },
    );
  }

  Future<void> makeTontineDeposit(double amount) {
    final syncId = const Uuid().v4();
    return _apiClient.post(
      '/tontine/deposit',
      body: {'amount': amount, 'source': 'wallet', 'syncId': syncId},
    );
  }

  Future<void> transferAvailableToTontine(double amount) {
    final syncId = const Uuid().v4();
    return _apiClient.post(
      '/tontine/deposit',
      body: {'amount': amount, 'source': 'wallet', 'syncId': syncId},
    );
  }

  Future<void> confirmTontinePayout() {
    return _apiClient.post('/tontine/confirm-payout');
  }

  Future<void> stopTontineEarly() {
    return _apiClient.post('/tontine/stop-early');
  }

  Future<void> createGoal(
    TontineGoal goal, {
    String? linkedOfferId,
    int quantity = 1,
    double? unitPrice,
  }) {
    return _apiClient.post(
      '/goals',
      body: {
        'title': goal.title,
        'targetAmount': goal.targetAmount,
        'iconCodePoint': goal.iconCodePoint,
        'colorValue': goal.colorValue,
        'endDate': goal.endDate.toIso8601String(),
        'startDate': goal.startDate.toIso8601String(),
        'linkedOfferId': linkedOfferId,
        'quantity': quantity,
        'unitPrice': unitPrice,
      },
    );
  }

  Future<void> fundGoal(String goalId, double amount) {
    return _apiClient.post('/goals/$goalId/fund', body: {'amount': amount});
  }

  Future<void> closeGoal(String goalId) {
    return _apiClient.post('/goals/$goalId/close');
  }

  Future<WithdrawalRequestResult> requestWithdrawal(
    double amount, {
    String channel = 'agent_cash',
  }) async {
    final data = await _apiClient.post(
      '/withdrawals',
      body: {'amount': amount, 'channel': channel},
    ) as Map<dynamic, dynamic>;

    return WithdrawalRequestResult.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<List<PaymentMethodOption>> fetchPaymentMethods(
    String operation,
  ) async {
    try {
      final payload = _asMap(
        await _apiClient.get(
          '/payment-methods?operation=${Uri.encodeComponent(operation)}',
        ),
      );
      final methods = _asList(payload['items']);
      return methods
          .whereType<Map>()
          .map(
            (entry) => PaymentMethodOption.fromMap(
              Map<dynamic, dynamic>.from(entry),
            ),
          )
          .toList();
    } catch (_) {
      return _fallbackPaymentMethods(operation);
    }
  }

  Future<WithdrawalRequestResult> regenerateWithdrawalCode(
    String withdrawalId,
  ) async {
    final data = await _apiClient.post(
      '/withdrawals/$withdrawalId/regenerate-code',
    ) as Map<dynamic, dynamic>;

    return WithdrawalRequestResult.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<void> cancelWithdrawal(String withdrawalId, {String? reason}) {
    return _apiClient.post(
      '/withdrawals/$withdrawalId/cancel',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> buyMarketplaceOfferNow(MarketOffer offer, {int quantity = 1}) {
    return _apiClient.post(
      '/marketplace/orders',
      body: {'offerId': offer.id, 'quantity': quantity},
    );
  }

  Future<void> createGoalFromMarketplaceOffer(
    MarketOffer offer, {
    int quantity = 1,
  }) {
    final unitPrice = offer.price ?? 0;
    return createGoal(
      TontineGoal(
        id: '',
        title: offer.title,
        targetAmount: unitPrice * quantity,
        currentAmount: 0,
        iconCodePoint: 58780,
        colorValue: 0xFF10A890,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
      ),
      linkedOfferId: offer.id,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  Future<void> advanceOrder(String orderId) {
    return _apiClient.post('/marketplace/orders/$orderId/advance');
  }

  Future<void> cancelOrder(String orderId) {
    return _apiClient.post('/marketplace/orders/$orderId/cancel');
  }

  Future<void> toggleFavorite(String offerId) {
    return _apiClient.post('/marketplace/favorites/$offerId/toggle');
  }

  Future<void> saveUserProfile(UserProfile profile) {
    return _apiClient.patch(
      '/profile',
      body: {
        'displayName': profile.displayName,
        'phoneNumber': profile.phoneNumber,
        'accountType': profile.accountType,
      },
    );
  }

  Future<void> savePreferences(ProfilePreferences preferences) {
    return _apiClient.patch('/profile/preferences', body: preferences.toMap());
  }

  Future<void> markNotificationAsRead(String notificationId) {
    return _apiClient.post('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsAsRead() {
    return _apiClient.post('/notifications/read-all');
  }

  TontineGoal _goalFromApi(dynamic entry) {
    final map = _asMap(entry);
    final transactions = _asList(
      map['transactions'],
    ).map((transaction) => _goalTransactionFromApi(transaction)).toList();

    return TontineGoal(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      targetAmount: _toDouble(map['targetAmount']),
      currentAmount: _toDouble(map['currentAmount']),
      iconCodePoint: _toInt(map['iconCodePoint']),
      colorValue: _toInt(map['colorValue']),
      isPriority: map['isPriority'] as bool? ?? false,
      status: GoalStatus.values.firstWhere(
        (value) => value.name == (map['status'] as String? ?? 'active'),
        orElse: () => GoalStatus.active,
      ),
      transactions: transactions,
      startDate: _toDateTime(map['startDate']),
      endDate: _toDateTime(map['endDate']),
      linkedOfferId: map['linkedOfferId'] as String?,
      quantity: _toInt(map['quantity']).clamp(1, 999999).toInt(),
      unitPrice: map['unitPrice'] == null ? null : _toDouble(map['unitPrice']),
    );
  }

  TontineTransaction _goalTransactionFromApi(dynamic entry) {
    final map = _asMap(entry);
    return TontineTransaction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: _toDouble(map['amount']),
      date: _toDateTime(map['occurredAt'] ?? map['date']),
      isDeposit: map['isDeposit'] as bool? ?? true,
    );
  }

  TontineCycle _cycleFromApi(Map<dynamic, dynamic> map) {
    return TontineCycle(
      stakeAmount: _toDouble(map['stakeAmount']),
      cumulativeAmount: _toDouble(map['cumulativeAmount']),
      status: TontineCycleStatus.values.firstWhere(
        (value) => value.name == (map['status'] as String? ?? 'active'),
        orElse: () => TontineCycleStatus.active,
      ),
      startedAt: map['startedAt'] == null
          ? null
          : _toDateTime(map['startedAt']),
      expectedEndAt: map['expectedEndAt'] == null
          ? null
          : _toDateTime(map['expectedEndAt']),
      endedAt: map['endedAt'] == null ? null : _toDateTime(map['endedAt']),
    );
  }

  TontineHistoryEntry _historyFromApi(dynamic entry) {
    final map = _asMap(entry);
    return TontineHistoryEntry(
      id: map['id'] as String? ?? '',
      type: TontineHistoryType.values.firstWhere(
        (value) => value.name == (map['type'] as String? ?? 'deposit'),
        orElse: () => TontineHistoryType.deposit,
      ),
      amount: _toDouble(map['amount']),
      date: _toDateTime(map['occurredAt'] ?? map['date']),
      label: map['label'] as String? ?? '',
      note: map['note'] as String?,
    );
  }

  TontineArchiveEntry _archiveFromApi(dynamic entry) {
    final map = _asMap(entry);
    return TontineArchiveEntry(
      id: map['id'] as String? ?? '',
      startDate: _toDateTime(map['startedAt'] ?? map['startDate']),
      expectedEndDate: map['expectedEndAt'] == null
          ? null
          : _toDateTime(map['expectedEndAt']),
      endDate: _toDateTime(map['endedAt'] ?? map['endDate']),
      stakeAmount: _toDouble(map['stakeAmount']),
      targetAmount: _toDouble(map['targetAmount']),
      cumulativeAmount: _toDouble(map['cumulativeAmount']),
      commissionAmount: _toDouble(map['commissionAmount']),
      netPayoutAmount: _toDouble(map['netPayoutAmount']),
      status: TontineArchiveStatus.values.firstWhere(
        (value) => value.name == (map['status'] as String? ?? 'completed'),
        orElse: () => TontineArchiveStatus.completed,
      ),
    );
  }

  AvailableBalanceHistoryEntry _walletHistoryFromApi(dynamic entry) {
    final map = _asMap(entry);
    return AvailableBalanceHistoryEntry(
      id: map['id'] as String? ?? '',
      type: AvailableBalanceHistoryType.values.firstWhere(
        (value) => value.name == (map['type'] as String? ?? 'goalFunding'),
        orElse: () => AvailableBalanceHistoryType.goalFunding,
      ),
      amount: _toDouble(map['amount']),
      date: _toDateTime(map['occurredAt'] ?? map['date']),
      label: map['label'] as String? ?? '',
      isCredit: map['isCredit'] as bool? ?? false,
    );
  }

  WithdrawalSummary _withdrawalFromApi(dynamic entry) {
    final map = _asMap(entry);
    return WithdrawalSummary.fromMap(map);
  }

  MarketOrder _marketOrderFromApi(dynamic entry) {
    final map = _asMap(entry);
    return MarketOrder(
      id: map['id'] as String? ?? '',
      offerId: map['offerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: _toDouble(map['amount']),
      quantity: _toInt(map['quantity']).clamp(1, 999999),
      unitPrice: _toDouble(map['unitPrice']),
      date: _toDateTime(map['orderedAt'] ?? map['date']),
      status: MarketOrderStatus.values.firstWhere(
        (value) => value.name == (map['status'] as String? ?? 'pending'),
        orElse: () => MarketOrderStatus.pending,
      ),
      updatedAt: map['updatedStatusAt'] == null
          ? null
          : _toDateTime(map['updatedStatusAt']),
    );
  }

  AppNotificationItem _notificationFromApi(dynamic entry) {
    final map = _asMap(entry);
    return AppNotificationItem(
      id: map['id'] as String? ?? '',
      type: AppNotificationType.values.firstWhere(
        (value) => value.name == (map['type'] as String? ?? 'system'),
        orElse: () => AppNotificationType.system,
      ),
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: _toDateTime(map['createdAtClient'] ?? map['createdAt']),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  UserProfile _profileFromApi(Map<dynamic, dynamic> map) {
    return UserProfile(
      displayName: map['displayName'] as String? ?? 'Utilisateur VizioBox',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      accountType: map['accountType'] as String? ?? 'Personnel',
      memberSince: _toDateTime(map['memberSince']),
      lastLoginAt: map['lastLoginAt'] == null
          ? null
          : _toDateTime(map['lastLoginAt']),
      kyc: KycSummary.fromMap(map['kyc'] is Map ? map['kyc'] as Map : null),
    );
  }

  ProfilePreferences _preferencesFromApi(Map<dynamic, dynamic> map) {
    return ProfilePreferences(
      depositNotificationsEnabled:
          map['depositNotificationsEnabled'] as bool? ?? true,
      cycleNotificationsEnabled:
          map['cycleNotificationsEnabled'] as bool? ?? true,
      marketingNotificationsEnabled:
          map['marketingNotificationsEnabled'] as bool? ?? false,
      pinEnabled: map['pinEnabled'] as bool? ?? false,
      biometricEnabled: map['biometricEnabled'] as bool? ?? false,
      pinCode: map['pinCode'] as String?,
    );
  }

  List<PaymentMethodOption> _fallbackPaymentMethods(String operation) {
    switch (operation) {
      case 'tontine_deposit':
        return const [
          PaymentMethodOption(
            id: 'fallback-wallet',
            code: 'wallet',
            label: 'Solde disponible',
            description: 'Transfert depuis le solde disponible du client.',
            provider: 'internal',
            operation: 'tontine_deposit',
            flowType: 'internal_transfer',
            enabled: true,
            sortOrder: 10,
          ),
          PaymentMethodOption(
            id: 'fallback-fedapay',
            code: 'fedapay',
            label: 'FedaPay',
            description: 'Paiement externe via FedaPay.',
            provider: 'fedapay',
            operation: 'tontine_deposit',
            flowType: 'external_checkout',
            enabled: true,
            sortOrder: 20,
          ),
          PaymentMethodOption(
            id: 'fallback-afrikmoney',
            code: 'afrikmoney',
            label: 'Afrikmoney',
            description: 'Paiement externe via Afrikmoney.',
            provider: 'afrikmoney',
            operation: 'tontine_deposit',
            flowType: 'external_checkout',
            enabled: true,
            sortOrder: 40,
          ),
          PaymentMethodOption(
            id: 'fallback-mtn-momo',
            code: 'mtn_momo',
            label: 'MTN MoMo',
            description: 'Paiement externe via MTN MoMo.',
            provider: 'mtn_momo',
            operation: 'tontine_deposit',
            flowType: 'external_checkout',
            enabled: true,
            sortOrder: 30,
          ),
        ];
      case 'withdrawal':
        return const [
          PaymentMethodOption(
            id: 'fallback-agent-cash',
            code: 'agent_cash',
            label: 'Agent / caisse',
            description: 'Retrait validé puis payé par un agent.',
            provider: 'internal',
            operation: 'withdrawal',
            flowType: 'manual_review',
            enabled: true,
            sortOrder: 10,
          ),
          PaymentMethodOption(
            id: 'fallback-mobile-money',
            code: 'mobile_money',
            label: 'Mobile money',
            description: 'Retrait payé hors application via mobile money.',
            provider: 'mobile_money',
            operation: 'withdrawal',
            flowType: 'manual_review',
            enabled: true,
            sortOrder: 20,
          ),
          PaymentMethodOption(
            id: 'fallback-bank-transfer',
            code: 'bank_transfer',
            label: 'Virement bancaire',
            description: 'Retrait payé hors application via virement bancaire.',
            provider: 'bank_transfer',
            operation: 'withdrawal',
            flowType: 'manual_review',
            enabled: true,
            sortOrder: 30,
          ),
        ];
      default:
        return const <PaymentMethodOption>[];
    }
  }

  Map<dynamic, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return <dynamic, dynamic>{};
  }

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) {
      return List<dynamic>.from(raw);
    }
    return <dynamic>[];
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}
