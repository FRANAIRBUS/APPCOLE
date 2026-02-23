import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class InviteService {
  InviteService(this._functions);

  final FirebaseFunctions _functions;

  Future<void> redeemInviteCode({
    required String code,
    required String childName,
    required int childAge,
    String? classId,
  }) async {
    final schoolId = Firebase.app().options.projectId;
    await _functions.httpsCallable('redeemInviteCode').call({
      if (schoolId.isNotEmpty) 'schoolId': schoolId,
      'code': code,
      'childName': childName,
      'childAge': childAge,
      'classId': classId,
    });
  }
}
