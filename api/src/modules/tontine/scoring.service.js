const { User } = require('../../database/models');
const { QueryTypes } = require('sequelize');
const sequelize = require('../../config/database');

/**
 * Adjust the user's score and ensure it stays within 0 and 100
 */
async function _adjustScore(userId, points, transaction) {
  const user = await User.findByPk(userId, { transaction });
  if (!user) return;

  let newScore = user.punctualityScore + points;
  if (newScore > 100) newScore = 100;
  if (newScore < 0) newScore = 0;

  await user.update({ punctualityScore: newScore }, { transaction });
}

/**
 * Penalty for stopping a cycle early.
 */
async function penalizeEarlyStop(userId, transaction) {
  await _adjustScore(userId, -20, transaction);
}

/**
 * Evaluates a completed cycle based on how many distinct days the user made a deposit.
 */
async function evaluateCompletedCycle(userId, cycleId, transaction) {
  // Count the number of distinct days the user made a deposit for this cycle
  const result = await sequelize.query(
    `SELECT COUNT(DISTINCT DATE(occurred_at)) AS daysCount 
     FROM tontine_histories 
     WHERE cycle_id = :cycleId 
       AND user_id = :userId 
       AND type = 'deposit'`,
    {
      replacements: { cycleId, userId },
      type: QueryTypes.SELECT,
      transaction,
    }
  );

  const daysCount = result.length > 0 ? parseInt(result[0].daysCount || 0) : 0;

  let pointsToAward = 0;
  if (daysCount >= 25) {
    pointsToAward = 10;
  } else if (daysCount >= 15) {
    pointsToAward = 5;
  } else {
    pointsToAward = -5;
  }

  await _adjustScore(userId, pointsToAward, transaction);
}

module.exports = {
  penalizeEarlyStop,
  evaluateCompletedCycle,
};
