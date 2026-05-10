function truncateTo2(value) {
  const numericValue = Number(value || 0);
  return Math.trunc(numericValue * 100) / 100;
}

function computeTargetAmount(stakeAmount) {
  return Number(stakeAmount) * 31;
}

function computeCycleCap(cycleCommissionAmount, shareRate) {
  return truncateTo2(Number(cycleCommissionAmount) * Number(shareRate || 0));
}

function computeProgressAmount(amount, totalAmount, capAmount) {
  if (!amount || !totalAmount || !capAmount) {
    return 0;
  }

  return truncateTo2((Number(amount) / Number(totalAmount)) * Number(capAmount));
}

function computeFloatingAmount({
  cycleCommissionAmount,
  depositConsumed,
  platformConsumed,
  reserveAmount,
  bonusAmount,
}) {
  return truncateTo2(
    Number(cycleCommissionAmount || 0) -
      Number(depositConsumed || 0) -
      Number(platformConsumed || 0) -
      Number(reserveAmount || 0) -
      Number(bonusAmount || 0),
  );
}

function computeReserveConsumption({
  principalConsumed,
  sourceAmount,
  initialReservedAmount,
  withdrawalAgentShareRate,
  platformShareRate,
}) {
  const ratio =
    Number(sourceAmount) > 0 ? Number(principalConsumed) / Number(sourceAmount) : 0;
  const commissionConsumed = truncateTo2(ratio * Number(initialReservedAmount || 0));
  const totalOperationalRate =
    Number(withdrawalAgentShareRate || 0) + Number(platformShareRate || 0);
  const platformRatio =
    totalOperationalRate > 0 ? Number(platformShareRate || 0) / totalOperationalRate : 0;
  const platformCommissionAmount = truncateTo2(commissionConsumed * platformRatio);
  const agentCommissionAmount = truncateTo2(
    commissionConsumed - platformCommissionAmount,
  );

  return {
    ratio,
    commissionConsumed,
    agentCommissionAmount,
    platformCommissionAmount,
  };
}

function planReserveConsumptions({ reserves, withdrawalAmount }) {
  let remainingPrincipal = truncateTo2(withdrawalAmount);
  const consumptions = [];
  const updatedReserves = [];

  for (const reserve of reserves) {
    const nextReserve = { ...reserve };

    if (remainingPrincipal <= 0) {
      updatedReserves.push(nextReserve);
      continue;
    }

    const reservePrincipalAvailable = Number(nextReserve.remainingSourceAmount || 0);
    const reserveCommissionAvailable = Number(nextReserve.availableAmount || 0);
    if (reservePrincipalAvailable <= 0 || reserveCommissionAvailable <= 0) {
      updatedReserves.push(nextReserve);
      continue;
    }

    const principalConsumed = Math.min(remainingPrincipal, reservePrincipalAvailable);
    const breakdown = computeReserveConsumption({
      principalConsumed,
      sourceAmount: nextReserve.sourceAmount,
      initialReservedAmount: nextReserve.initialReservedAmount,
      withdrawalAgentShareRate: nextReserve.withdrawalAgentShareRate,
      platformShareRate: nextReserve.platformShareRate,
    });

    nextReserve.remainingSourceAmount = truncateTo2(
      reservePrincipalAvailable - principalConsumed,
    );
    nextReserve.consumedSourceAmount = truncateTo2(
      Number(nextReserve.consumedSourceAmount || 0) + principalConsumed,
    );
    nextReserve.availableAmount = truncateTo2(
      reserveCommissionAvailable - breakdown.commissionConsumed,
    );
    nextReserve.consumedAmount = truncateTo2(
      Number(nextReserve.consumedAmount || 0) + breakdown.commissionConsumed,
    );
    nextReserve.status = nextReserve.remainingSourceAmount <= 0 ? 'consumed' : 'open';

    consumptions.push({
      reserveId: nextReserve.id,
      cycleId: nextReserve.cycleId,
      principalConsumed,
      commissionConsumed: breakdown.commissionConsumed,
      agentCommissionAmount: breakdown.agentCommissionAmount,
      platformCommissionAmount: breakdown.platformCommissionAmount,
    });

    remainingPrincipal = truncateTo2(remainingPrincipal - principalConsumed);
    updatedReserves.push(nextReserve);
  }

  return {
    fullyCovered: remainingPrincipal <= 0,
    remainingPrincipal,
    consumptions,
    updatedReserves,
  };
}

module.exports = {
  truncateTo2,
  computeTargetAmount,
  computeCycleCap,
  computeProgressAmount,
  computeFloatingAmount,
  computeReserveConsumption,
  planReserveConsumptions,
};
