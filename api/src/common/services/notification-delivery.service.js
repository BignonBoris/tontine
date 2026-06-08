const {
  publishNotificationCreated,
} = require('./realtime-notification.service');
const {
  sendPushNotificationToUser,
} = require('./fcm-push.service');

function deliverNotificationCreated(notification) {
  const payload = publishNotificationCreated(notification);

  void sendPushNotificationToUser(notification).catch((error) => {
    console.error(
      `Echec de diffusion push pour la notification ${notification?.id || 'unknown'}:`,
      error,
    );
  });

  return payload;
}

module.exports = { deliverNotificationCreated };
