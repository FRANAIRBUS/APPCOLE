import 'package:cloud_functions/cloud_functions.dart';

class InviteService {
  InviteService(this._functions);

  final FirebaseFunctions _functions;

  Future<void> redeemInviteCode({
    required String code,
    required String childName,
    required int childAge,
    String? classId,
  }) async {
    await _functions.httpsCallable('redeemInviteCode').call({
      'code': code,
      'childName': childName,
      'childAge': childAge,
      'classId': classId,
    });
  }
}
