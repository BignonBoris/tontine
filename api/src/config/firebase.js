const admin = require('firebase-admin');
let serviceAccount;

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // Option 1: Parse from a JSON string
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
  // Option 2: Use individual env variables
  serviceAccount = {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  };
} else {
  // Fallback to local file for development
  try {
    serviceAccount = require('../../service-account.json');
  } catch (err) {
    console.error('Missing Firebase credentials. Please set FIREBASE_SERVICE_ACCOUNT or provide service-account.json');
  }
}

if (serviceAccount) {
  admin.initializeApp({
    credential: admin.cert(serviceAccount),
  });
}

module.exports = admin;