export interface AdminSession {
  username: string;
  role: string;
}

export interface AuthLoginPayload {
  username: string;
  password: string;
}

export interface OverviewChartPoint {
  label: string;
  value: number;
}

export interface AuditLogItem {
  id: string;
  action: string;
  entityType: string;
  entityId: string | null;
  status: string;
  ipAddress: string | null;
  createdAt: string;
  user: {
    id: string;
    displayName: string;
    phoneNumber: string;
  } | null;
}

export interface OverviewData {
  totals: {
    totalClients: number;
    activeClients: number;
    totalAgents: number;
    activeAgents: number;
    pendingWithdrawals: number;
    totalRequestedWithdrawals: number;
    totalPaidWithdrawals: number;
    totalAvailableBalances: number;
    totalAgentBalances: number;
    totalReservedWithdrawals: number;
  };
  charts: {
    newClients: OverviewChartPoint[];
    withdrawalVolumes: OverviewChartPoint[];
    withdrawalStatusBreakdown: OverviewChartPoint[];
  };
  recentAuditLogs: AuditLogItem[];
}

export interface MarketplaceOverviewItem {
  offerId: string;
  title: string;
  category: string | null;
  brand: string | null;
  unitPrice: number;
  isActive: boolean;
  directOrders: {
    totalOrders: number;
    totalOrderedQuantity: number;
    inFlightQuantity: number;
    deliveredQuantity: number;
    cancelledQuantity: number;
    pendingQuantity: number;
    confirmedQuantity: number;
    readyQuantity: number;
    lastOrderedAt: string | null;
  };
  linkedGoals: {
    totalGoals: number;
    activeGoals: number;
    closedGoals: number;
    plannedQuantity: number;
    activePlannedQuantity: number;
    fundedAmount: number;
    targetAmount: number;
    nearestEndDate: string | null;
    farthestEndDate: string | null;
    progressRate: number;
  };
}

export interface MarketplaceOverviewData {
  totals: {
    offers: number;
    activeOffers: number;
    inFlightOrderedQuantity: number;
    activePlannedGoalQuantity: number;
  };
  items: MarketplaceOverviewItem[];
}

export interface MarketplaceOrderLineItem {
  id: string;
  offerId: string;
  title: string;
  quantity: number;
  unitPrice: number;
  amount: number;
  status: string;
  orderedAt: string;
  updatedStatusAt: string | null;
  offer: {
    id: string;
    title: string;
    category: string | null;
    brand: string | null;
    isActive: boolean;
  } | null;
  client: {
    id: string;
    displayName: string;
    phoneNumber: string;
  } | null;
}

export interface MarketplaceGoalLineItem {
  id: string;
  title: string;
  linkedOfferId: string | null;
  quantity: number;
  unitPrice: number;
  targetAmount: number;
  currentAmount: number;
  progress: number;
  status: string;
  startDate: string;
  endDate: string;
  linkedOffer: {
    id: string;
    title: string;
    category: string | null;
    brand: string | null;
    isActive: boolean;
  } | null;
  client: {
    id: string;
    displayName: string;
    phoneNumber: string;
  } | null;
}

export interface MarketplaceOfferAdminItem {
  id: string;
  title: string;
  description: string;
  descriptionHtml?: string | null;
  imageUrl: string;
  category: string;
  brand: string | null;
  price: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface OperationalAnomalies {
  counts: {
    staleWithdrawals: number;
    expiredRequestedWithdrawals: number;
    walletReservationMismatches: number;
    inactiveAgentsWithCash: number;
    overdueActiveCycles: number;
  };
  staleWithdrawals: Array<{
    id: string;
    reference: string;
    amount: number;
    requestedAt: string;
    client: {
      id: string;
      displayName: string;
      phoneNumber: string;
    };
  }>;
  expiredRequestedWithdrawals: Array<{
    id: string;
    reference: string;
    amount: number;
    confirmationCodeExpiresAt: string;
    confirmationCodeAttempts: number;
    client: {
      id: string;
      displayName: string;
      phoneNumber: string;
    };
  }>;
  walletReservationMismatches: Array<{
    userId: string;
    client: {
      id: string;
      displayName: string;
      phoneNumber: string;
    } | null;
    reservedBalance: number;
    requestedAmount: number;
    gapAmount: number;
  }>;
  inactiveAgentsWithCash: Array<{
    id: string;
    agentCode: string;
    fullName: string;
    phoneNumber: string | null;
    agentBalance: number;
  }>;
  overdueActiveCycles: Array<{
    id: string;
    status: string;
    cumulativeAmount: number;
    expectedEndAt: string;
    client: {
      id: string;
      displayName: string;
      phoneNumber: string;
    } | null;
  }>;
}

export interface ClientItem {
  id: string;
  displayName: string;
  phoneNumber: string;
  accountType: string;
  address: string | null;
  isActive: boolean;
  memberSince: string;
  createdAt: string;
  availableBalance: number;
  reservedWithdrawalBalance: number;
  tontineBalance: number;
  createdByAgent: {
    id: string;
    agentCode: string;
    fullName: string;
  } | null;
}

export interface ClientDetail {
  client: {
    id: string;
    displayName: string;
    phoneNumber: string;
    accountType: string;
    address: string | null;
    isActive: boolean;
    memberSince: string;
    createdAt: string;
    wallet: {
      availableBalance: number;
      reservedWithdrawalBalance: number;
      tontineBalance: number;
    };
    createdByAgent: {
      id: string;
      agentCode: string;
      fullName: string;
    } | null;
  };
  cycles: Array<{
    id: string;
    stakeAmount: number;
    cumulativeAmount: number;
    status: string;
    startedAt: string;
    expectedEndAt: string;
    endedAt: string | null;
  }>;
  goals: Array<{
    id: string;
    title: string;
    linkedOfferId: string | null;
    linkedOffer: {
      id: string;
      title: string;
      category: string | null;
      brand: string | null;
    } | null;
    quantity: number;
    unitPrice: number;
    targetAmount: number;
    currentAmount: number;
    progress: number;
    status: string;
    startDate: string;
    endDate: string;
  }>;
  withdrawals: Array<{
    id: string;
    reference: string;
    amount: number;
    status: string;
    requestedAt: string;
    paidAt: string | null;
    cancelledAt: string | null;
  }>;
  balanceHistory: Array<{
    id: string;
    type: string;
    amount: number;
    label: string;
    isCredit: boolean;
    occurredAt: string;
  }>;
  tontineHistory: Array<{
    id: string;
    type: string;
    amount: number;
    label: string;
    note: string | null;
    occurredAt: string;
  }>;
}

export interface AgentItem {
  id: string;
  userId: string;
  agentCode: string;
  fullName: string;
  phoneNumber: string | null;
  isActive: boolean;
  agentBalance: number;
  createdAt: string;
  createdClientsCount: number;
}

export interface AgentTopUpResult {
  agent: {
    id: string;
    userId: string;
    agentCode: string;
    fullName: string;
  };
  topUp: {
    reference: string;
    amount: number;
    reason: string;
    occurredAt: string;
    agentBalanceBefore: number;
    agentBalanceAfter: number;
    initiatedByAdminUsername: string | null;
  };
}

export interface AgentCashHistoryItem {
  id: string;
  reference: string;
  type: string;
  amount: number;
  isCredit: boolean;
  balanceBefore: number;
  balanceAfter: number;
  label: string;
  note: string | null;
  relatedEntityType: string | null;
  relatedEntityId: string | null;
  initiatorType: string | null;
  occurredAt: string;
}

export interface AgentCashHistoryResponse {
  agent: {
    id: string;
    userId: string;
    agentCode: string;
    fullName: string;
    phoneNumber: string | null;
    isActive: boolean;
    agentBalance: number;
    createdAt: string;
  };
  history: {
    items: AgentCashHistoryItem[];
    pagination: {
      page: number;
      pageSize: number;
      total: number;
    };
  };
}

export interface WithdrawalItem {
  id: string;
  reference: string;
  amount: number;
  status: string;
  channel: string;
  requestedAt: string;
  paidAt: string | null;
  cancelledAt: string | null;
  initiatorType: string | null;
  cancellationReason: string | null;
  client: {
    id: string;
    displayName: string;
    phoneNumber: string;
  } | null;
}

export interface WithdrawalDetail {
  withdrawal: WithdrawalItem & {
    paidBy: {
      id: string;
      displayName: string;
      phoneNumber: string;
      agentCode: string | null;
    } | null;
    initiatedByUserId: string | null;
    paidByAgentProfileId: string | null;
    confirmationCodeExpiresAt: string;
    confirmationCodeAttempts: number;
    isConfirmationCodeExpired: boolean;
    clientWalletSnapshot: {
      availableBalance: number;
      reservedWithdrawalBalance: number;
    };
  };
  auditLogs: Array<{
    id: string;
    action: string;
    status: string;
    ipAddress: string | null;
    createdAt: string;
    user: {
      id: string;
      displayName: string;
      phoneNumber: string;
    } | null;
  }>;
}
