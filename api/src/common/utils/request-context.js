function getRequestContext(req) {
  return {
    ipAddress: req.ip || null,
    userAgent: req.get('user-agent') || null,
  };
}

module.exports = { getRequestContext };
