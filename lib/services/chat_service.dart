import 'package:cloud_functions/cloud_functions.dart';

class ChatService {
  ChatService(this._functions);

  final FirebaseFunctions _functions;

  Future<String> getOrCreateChat({required String schoolId, required String peerUid}) async {
    final callable = _functions.httpsCallable('getOrCreateChat');
    final response = await callable.call<Map<String, dynamic>>({
      'schoolId': schoolId,
      'peerUid': peerUid,
    });

    final chatId = response.data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) {
      throw FirebaseFunctionsException(code: 'internal', message: 'No se pudo crear/leer el chat');
    }

    return chatId;
  }
}
