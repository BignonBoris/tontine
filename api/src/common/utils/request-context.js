function getRequestContext(req) {
  const accountType = String(req.auth?.accountType || '').toLowerCase();
  let initiatorType = 'client';

  if (accountType === 'agent') {
    initiatorType = 'agent';
  } else if (accountType === 'admin' || accountType === 'superviseur') {
    initiatorType = 'admin';
  }

  return {
    ipAddress: req.ip || null,
    userAgent: req.get('user-agent') || null,
    initiatedByUserId: req.auth?.userId || null,
    initiatorType,
  };
}

module.exports = { getRequestContext };
