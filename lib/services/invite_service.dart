import 'package:cloud_functions/cloud_functions.dart';

class InviteService {
  InviteService(this._functions);

  final FirebaseFunctions _functions;

  Future<String> redeemInviteCode(String code) async {
    final callable = _functions.httpsCallable('redeemInviteCode');
    final response = await callable.call<Map<String, dynamic>>({'code': code.trim()});
    final schoolId = response.data['schoolId'] as String?;
    if (schoolId == null || schoolId.isEmpty) {
      throw FirebaseFunctionsException(code: 'invalid-argument', message: 'schoolId inválido');
    }
    return schoolId;
  }
}
