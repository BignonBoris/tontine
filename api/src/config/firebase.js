const admin = require('firebase-admin');
const serviceAccount = require('../../service-account.json');

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

module.exports = admin;