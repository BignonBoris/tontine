const PAYMENT_METHOD_OPERATIONS = ['tontine_deposit', 'withdrawal'];

const PAYMENT_METHOD_FLOW_TYPES = [
  'internal_transfer',
  'external_checkout',
  'manual_review',
];

const DEFAULT_PAYMENT_METHODS = [
  {
    code: 'wallet',
    label: 'Solde disponible',
    description: 'Transfert depuis le solde disponible du client.',
    provider: 'internal',
    operation: 'tontine_deposit',
    flowType: 'internal_transfer',
    enabled: true,
    sortOrder: 10,
    metadata: {
      target: 'wallet',
    },
  },
  {
    code: 'fedapay',
    label: 'FedaPay',
    description: 'Paiement externe via FedaPay.',
    provider: 'fedapay',
    operation: 'tontine_deposit',
    flowType: 'external_checkout',
    enabled: true,
    sortOrder: 20,
    metadata: {
      target: 'fedapay',
    },
  },
  {
    code: 'mtn_momo',
    label: 'MTN MoMo',
    description: 'Paiement externe via MTN MoMo.',
    provider: 'mtn_momo',
    operation: 'tontine_deposit',
    flowType: 'external_checkout',
    enabled: false,
    sortOrder: 30,
    metadata: {
      target: 'mtn_momo',
    },
  },
  {
    code: 'afrikmoney',
    label: 'Afrikmoney',
    description: 'Paiement externe via Afrikmoney.',
    provider: 'afrikmoney',
    operation: 'tontine_deposit',
    flowType: 'external_checkout',
    enabled: false,
    sortOrder: 40,
    metadata: {
      target: 'afrikmoney',
    },
  },
  {
    code: 'agent_cash',
    label: 'Agent / caisse',
    description: 'Retrait valide puis paye par un agent.',
    provider: 'internal',
    operation: 'withdrawal',
    flowType: 'manual_review',
    enabled: true,
    sortOrder: 10,
    metadata: {
      target: 'agent_cash',
    },
  },
  {
    code: 'mobile_money',
    label: 'Mobile money',
    description: 'Retrait paye hors application via mobile money.',
    provider: 'mobile_money',
    operation: 'withdrawal',
    flowType: 'manual_review',
    enabled: true,
    sortOrder: 20,
    metadata: {
      target: 'mobile_money',
    },
  },
  {
    code: 'bank_transfer',
    label: 'Virement bancaire',
    description: 'Retrait paye hors application via virement bancaire.',
    provider: 'bank_transfer',
    operation: 'withdrawal',
    flowType: 'manual_review',
    enabled: true,
    sortOrder: 30,
    metadata: {
      target: 'bank_transfer',
    },
  },
];

module.exports = {
  PAYMENT_METHOD_OPERATIONS,
  PAYMENT_METHOD_FLOW_TYPES,
  DEFAULT_PAYMENT_METHODS,
};
