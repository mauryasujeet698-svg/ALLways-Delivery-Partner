import 'package:cloud_functions/cloud_functions.dart';

/// Server-authoritative partner shift state.
/// Location collection must not start until the server has accepted the shift.
class PartnerShiftService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  static Future<void> setShift({
    required String role,
    required bool online,
  }) async {
    final callable = _functions.httpsCallable(
      'setPartnerShift',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final result = await callable.call(<String, dynamic>{
      'role': role,
      'online': online,
    });
    final payload = result.data;
    if (payload is! Map || payload['ok'] != true) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'The server did not confirm the shift change.',
      );
    }
  }

  static Future<void> acceptRide({required String rideId}) async {
    final callable = _functions.httpsCallable(
      'acceptRide',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final result = await callable.call(<String, dynamic>{'rideId': rideId});
    final payload = result.data;
    if (payload is! Map || payload['ok'] != true) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'The server did not confirm the ride assignment.',
      );
    }
  }
}
