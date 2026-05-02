const AppError = require('../errors/app-error');

function errorHandler(error, req, res, next) {
  if (error instanceof AppError) {
    return res.status(error.statusCode).json({
      success: false,
      message: error.message,
      details: error.details,
    });
  }

  return res.status(500).json({
    success: false,
    message: 'Une erreur interne est survenue.',
    details:
      process.env.NODE_ENV === 'development'
        ? { stack: error.stack, message: error.message }
        : null,
  });
}

module.exports = errorHandler;
