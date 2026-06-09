const marketOffersSeed = require('./market-offers.seed');
const { hashPin } = require('../../modules/agent-auth/agent-auth.service');
const { normalizePhone } = require('../../modules/auth/auth.service');

async function runSeeds(models) {
  const { MarketOffer, User, UserPreference, Wallet, AgentProfile } = models;
  await Promise.all(
    marketOffersSeed.map((offer) =>
      MarketOffer.upsert({
        ...offer,
        isActive: true,
      }),
    ),
  );

  const legacyDefaultAgentPhone = '97000000';
  const defaultAgentPhone = normalizePhone(
    process.env.AGENT_DEFAULT_PHONE || '9700000000',
  );
  const defaultAgentPin = process.env.AGENT_DEFAULT_PIN || '1234';
  const defaultAgentCode = process.env.AGENT_DEFAULT_CODE || 'AGT-001';
  const defaultAgentName = process.env.AGENT_DEFAULT_NAME || 'Agent Demo';
  const defaultAgentBalance = Number(process.env.AGENT_DEFAULT_BALANCE || 0);

  if (defaultAgentPhone.length !== 10) {
    throw new Error(
      'AGENT_DEFAULT_PHONE doit contenir exactement 10 chiffres.',
    );
  }

  const existingUser =
    (await User.findOne({ where: { phoneNumber: defaultAgentPhone } })) ||
    (await User.findOne({ where: { phoneNumber: legacyDefaultAgentPhone } }));

  const user =
    existingUser ||
    (await User.create({
      phoneNumber: defaultAgentPhone,
      displayName: defaultAgentName,
      accountType: 'Agent',
      isActive: true,
    }));

  await user.update({
    phoneNumber: defaultAgentPhone,
    displayName: defaultAgentName,
    accountType: 'Agent',
    isActive: true,
  });

  await UserPreference.findOrCreate({
    where: { userId: user.id },
    defaults: { userId: user.id },
  });
  await Wallet.findOrCreate({
    where: { userId: user.id },
    defaults: { userId: user.id },
  });

  await AgentProfile.upsert({
    userId: user.id,
    agentCode: defaultAgentCode,
    pinHash: hashPin(defaultAgentPin),
    fullName: defaultAgentName,
    agentBalance: Number.isFinite(defaultAgentBalance)
      ? Math.max(defaultAgentBalance, 0)
      : 0,
    isActive: true,
  });

  return {
    phoneNumber: defaultAgentPhone,
    pin: defaultAgentPin,
    agentCode: defaultAgentCode,
    fullName: defaultAgentName,
  };
}

module.exports = runSeeds;
