const marketOffersSeed = require('./market-offers.seed');
const { hashPin } = require('../../modules/agent-auth/agent-auth.service');

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

  const defaultAgentPhone = process.env.AGENT_DEFAULT_PHONE || '97000000';
  const defaultAgentPin = process.env.AGENT_DEFAULT_PIN || '1234';
  const defaultAgentCode = process.env.AGENT_DEFAULT_CODE || 'AGT-001';
  const defaultAgentName = process.env.AGENT_DEFAULT_NAME || 'Agent Demo';
  const defaultAgentBalance = Number(process.env.AGENT_DEFAULT_BALANCE || 0);

  const [user] = await User.findOrCreate({
    where: { phoneNumber: defaultAgentPhone },
    defaults: {
      phoneNumber: defaultAgentPhone,
      displayName: defaultAgentName,
      accountType: 'Agent',
      isActive: true,
    },
  });

  await user.update({
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
