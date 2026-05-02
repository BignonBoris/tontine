// Import conditionnel : web → stub sans dépendance, mobile → implémentation réelle
export 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_mobile.dart';

