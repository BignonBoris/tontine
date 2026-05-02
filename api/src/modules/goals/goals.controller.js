const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./goals.service');

async function listGoals(req, res) {
  const data = await service.listGoals(req.auth.userId);
  return ok(res, data, 'Coffres charges.');
}

async function getGoal(req, res) {
  const data = await service.getGoal(req.auth.userId, req.params.goalId);
  return ok(res, data, 'Coffre charge.');
}

async function createGoal(req, res) {
  const data = await service.createGoal(
    req.auth.userId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Coffre cree.', 201);
}

async function fundGoal(req, res) {
  const data = await service.fundGoal(
    req.auth.userId,
    req.params.goalId,
    Number(req.body.amount),
    getRequestContext(req),
  );
  return ok(res, data, 'Coffre alimente.');
}

async function closeGoal(req, res) {
  const data = await service.closeGoal(
    req.auth.userId,
    req.params.goalId,
    getRequestContext(req),
  );
  return ok(res, data, 'Coffre cloture.');
}

async function depositGoalDirectly(req, res) {
  const data = await service.depositGoalDirectly(
    req.auth.userId,
    req.params.goalId,
    Number(req.body.amount),
    getRequestContext(req),
  );
  return ok(res, data, 'Depot enregistre.');
}

module.exports = {
  listGoals,
  getGoal,
  createGoal,
  fundGoal,
  closeGoal,
  depositGoalDirectly,
};
