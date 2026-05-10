const assert = require('node:assert/strict');
const {
  truncateTo2,
  computeTargetAmount,
  computeCycleCap,
  computeProgressAmount,
  computeFloatingAmount,
  computeReserveConsumption,
  planReserveConsumptions,
} = require('../src/modules/commission/commission-calculator');

function run() {
  assert.equal(truncateTo2(50.45), 50.45);
  assert.equal(truncateTo2(50.95), 50.95);
  assert.equal(truncateTo2(50.105), 50.1);
  assert.equal(truncateTo2(50.109), 50.1);

  assert.equal(computeTargetAmount(1000), 31000);
  assert.equal(computeCycleCap(1000, 0.3), 300);
  assert.equal(computeCycleCap(1000, 0.1), 100);

  assert.equal(computeProgressAmount(20000, 31000, 300), 193.54);
  assert.equal(computeProgressAmount(11000, 31000, 300), 106.45);

  assert.equal(
    computeFloatingAmount({
      cycleCommissionAmount: 1000,
      depositConsumed: 200,
      platformConsumed: 200,
      reserveAmount: 200,
      bonusAmount: 100,
    }),
    300,
  );

  const reserveBreakdown = computeReserveConsumption({
    principalConsumed: 10000,
    sourceAmount: 20000,
    initialReservedAmount: 200,
    withdrawalAgentShareRate: 0.3,
    platformShareRate: 0.3,
  });

  assert.equal(reserveBreakdown.commissionConsumed, 100);
  assert.equal(reserveBreakdown.agentCommissionAmount, 50);
  assert.equal(reserveBreakdown.platformCommissionAmount, 50);

  const fifoPlan = planReserveConsumptions({
    withdrawalAmount: 12000,
    reserves: [
      {
        id: 'reserve-a',
        cycleId: 'cycle-a',
        sourceAmount: 10000,
        remainingSourceAmount: 10000,
        consumedSourceAmount: 0,
        initialReservedAmount: 100,
        availableAmount: 100,
        consumedAmount: 0,
        status: 'open',
        withdrawalAgentShareRate: 0.3,
        platformShareRate: 0.3,
      },
      {
        id: 'reserve-b',
        cycleId: 'cycle-b',
        sourceAmount: 20000,
        remainingSourceAmount: 20000,
        consumedSourceAmount: 0,
        initialReservedAmount: 200,
        availableAmount: 200,
        consumedAmount: 0,
        status: 'open',
        withdrawalAgentShareRate: 0.3,
        platformShareRate: 0.3,
      },
    ],
  });

  assert.equal(fifoPlan.fullyCovered, true);
  assert.equal(fifoPlan.remainingPrincipal, 0);
  assert.equal(fifoPlan.consumptions.length, 2);
  assert.equal(fifoPlan.consumptions[0].reserveId, 'reserve-a');
  assert.equal(fifoPlan.consumptions[0].principalConsumed, 10000);
  assert.equal(fifoPlan.consumptions[0].commissionConsumed, 100);
  assert.equal(fifoPlan.consumptions[1].reserveId, 'reserve-b');
  assert.equal(fifoPlan.consumptions[1].principalConsumed, 2000);
  assert.equal(fifoPlan.consumptions[1].commissionConsumed, 20);

  console.log('commission-calculator-ok');
}

run();
