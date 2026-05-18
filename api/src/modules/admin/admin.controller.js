const { ok } = require('../../common/utils/api-response');
const service = require('./admin.service');

async function overview(req, res) {
  const data = await service.getOverview();
  return ok(res, data, 'Vue globale admin chargee.');
}

async function marketplaceOverview(req, res) {
  const data = await service.getMarketplaceOverview();
  return ok(res, data, 'Vue marketplace admin chargee.');
}

async function marketplaceOrders(req, res) {
  const data = await service.listMarketplaceOrders(req.query);
  return ok(res, data, 'Commandes marketplace admin chargees.');
}

async function marketplaceGoals(req, res) {
  const data = await service.listMarketplaceGoals(req.query);
  return ok(res, data, 'Coffres marketplace admin charges.');
}

async function marketplaceOffers(req, res) {
  const data = await service.listMarketplaceOffers(req.query);
  return ok(res, data, 'Articles marketplace admin charges.');
}

async function createMarketplaceOffer(req, res) {
  const data = await service.createMarketplaceOffer(req.body, {
    ipAddress: req.ip || null,
    userAgent: req.get('user-agent') || null,
    adminUsername: req.admin?.username || null,
  });
  return ok(res, data, 'Article marketplace cree.', 201);
}

async function updateMarketplaceOffer(req, res) {
  const data = await service.updateMarketplaceOffer(req.params.offerId, req.body, {
    ipAddress: req.ip || null,
    userAgent: req.get('user-agent') || null,
    adminUsername: req.admin?.username || null,
  });
  return ok(res, data, 'Article marketplace mis a jour.');
}

async function updateMarketplaceOfferStatus(req, res) {
  const data = await service.updateMarketplaceOfferStatus(
    req.params.offerId,
    req.body,
    {
      ipAddress: req.ip || null,
      userAgent: req.get('user-agent') || null,
      adminUsername: req.admin?.username || null,
    },
  );
  return ok(res, data, 'Statut article marketplace mis a jour.');
}

async function clients(req, res) {
  const data = await service.listClients(req.query);
  return ok(res, data, 'Clients charges.');
}

async function clientDetail(req, res) {
  const data = await service.getClientDetail(req.params.userId);
  return ok(res, data, 'Detail client charge.');
}

async function updateClientStatus(req, res) {
  const data = await service.updateClientStatus(req.params.userId, req.body);
  return ok(res, data, 'Statut client mis a jour.');
}

async function agents(req, res) {
  const data = await service.listAgents(req.query);
  return ok(res, data, 'Agents charges.');
}

async function updateAgentStatus(req, res) {
  const data = await service.updateAgentStatus(req.params.agentId, req.body);
  return ok(res, data, 'Statut agent mis a jour.');
}

async function topUpAgentCash(req, res) {
  const data = await service.topUpAgentCash(req.params.agentId, req.body, {
    ipAddress: req.ip || null,
    userAgent: req.get('user-agent') || null,
    adminUsername: req.admin?.username || null,
  });
  return ok(res, data, 'Caisse agent approvisionnee par admin.', 201);
}

async function agentCashHistory(req, res) {
  const data = await service.getAgentCashHistory(req.params.agentId, req.query);
  return ok(res, data, 'Historique de caisse agent charge.');
}

async function reverseProvisioning(req, res) {
  const data = await service.reverseProvisioningForAdmin(
    req.params.provisioningId,
    req.body,
    {
      ipAddress: req.ip || null,
      userAgent: req.get('user-agent') || null,
      adminUsername: req.admin?.username || null,
    },
  );
  return ok(res, data, 'Provisioning corrige par admin.');
}

async function withdrawals(req, res) {
  const data = await service.listWithdrawals(req.query);
  return ok(res, data, 'Retraits charges.');
}

async function withdrawalDetail(req, res) {
  const data = await service.getWithdrawalDetail(req.params.withdrawalId);
  return ok(res, data, 'Detail retrait charge.');
}

async function anomalies(req, res) {
  const data = await service.getOperationalAnomalies();
  return ok(res, data, 'Anomalies operationnelles chargees.');
}

async function auditLogs(req, res) {
  const data = await service.listAuditLogs(req.query);
  return ok(res, data, 'Audit charge.');
}

module.exports = {
  overview,
  marketplaceOverview,
  marketplaceOrders,
  marketplaceGoals,
  marketplaceOffers,
  createMarketplaceOffer,
  updateMarketplaceOffer,
  updateMarketplaceOfferStatus,
  clients,
  clientDetail,
  updateClientStatus,
  agents,
  updateAgentStatus,
  topUpAgentCash,
  agentCashHistory,
  reverseProvisioning,
  withdrawals,
  withdrawalDetail,
  anomalies,
  auditLogs,
};
