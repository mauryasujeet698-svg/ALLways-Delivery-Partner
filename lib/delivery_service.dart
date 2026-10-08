import 'package:cloud_functions/cloud_functions.dart';

class DeliveryService {
  static final _functions = FirebaseFunctions.instance;

  static Future<void> acceptOrder({required String orderId}) async {
    final callable = _functions.httpsCallable('acceptDeliveryOrder');
    await callable.call(<String,dynamic>{'orderId':orderId});
  }

  static Future<void> updateStatus({required String orderId, required String status}) async {
    final callable = _functions.httpsCallable('updateDeliveryOrderStatus');
    await callable.call(<String,dynamic>{'orderId':orderId,'status':status});
  }

  static Future<void> verifyDeliveryPin({
    required String orderId,
    required String pin,
    required bool cashCollected,
  }) async {
    final callable = _functions.httpsCallable('verifyConfirmationPin');
    await callable.call(<String,dynamic>{
      'type':'delivery',
      'orderId':orderId,
      'id':orderId,
      'pin':pin,
      'cashCollected':cashCollected,
    });
  }
}
