const subscribers = new Set();

function normalizeNotification(notification) {
  if (!notification) {
    return null;
  }

  const plain = typeof notification.get === 'function'
    ? notification.get({ plain: true })
    : notification;

  if (!plain || !plain.userId) {
    return null;
  }

  return {
    id: plain.id || null,
    userId: String(plain.userId),
    type: plain.type || 'system',
    title: plain.title || '',
    message: plain.message || '',
    isRead: Boolean(plain.isRead),
    createdAtClient: plain.createdAtClient || null,
    createdAt: plain.createdAt || null,
    updatedAt: plain.updatedAt || null,
  };
}

function publishRealtimeEvent(eventName, notification) {
  const payload = normalizeNotification(notification);
  if (!payload) {
    return null;
  }

  for (const subscriber of subscribers) {
    if (subscriber.eventName !== eventName) {
      continue;
    }
    if (String(subscriber.userId) !== String(payload.userId)) {
      continue;
    }

    try {
      subscriber.listener(payload);
    } catch (error) {
      console.error(
        `Realtime notification subscriber failed for ${eventName}:`,
        error,
      );
    }
  }

  return payload;
}

function publishNotificationCreated(notification) {
  return publishRealtimeEvent('notification.created', notification);
}

function subscribeRealtimeEvent(userId, eventName, listener) {
  const subscription = {
    userId: String(userId),
    eventName,
    listener,
  };

  subscribers.add(subscription);

  return () => {
    subscribers.delete(subscription);
  };
}

function subscribeNotificationCreated(userId, listener) {
  return subscribeRealtimeEvent(userId, 'notification.created', listener);
}

module.exports = {
  publishNotificationCreated,
  publishRealtimeEvent,
  subscribeRealtimeEvent,
  subscribeNotificationCreated,
  normalizeNotification,
};
