import 'package:cloud_functions/cloud_functions.dart';

class DeliveryService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

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
    final result = await callable.call(<String,dynamic>{
      'type':'delivery',
      'orderId':orderId,
      'id':orderId,
      'pin':pin,
      'cashCollected':cashCollected,
    });
    final payload = result.data;
    if (payload is! Map || (payload['verified'] != true && payload['ok'] != true)) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'The server did not confirm this PIN. Please try again.',
      );
    }
  }
}
