import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatService {
  ChatService(this._functions);

  final FirebaseFunctions _functions;

  Future<String> getOrCreateChat({String? schoolId, required String peerUid}) async {
    final callable = _functions.httpsCallable('getOrCreateChat');
    final response = await callable.call<Map<String, dynamic>>({
      if (schoolId != null && schoolId.trim().isNotEmpty) 'schoolId': schoolId.trim(),
      'peerUid': peerUid,
    });

    final chatId = response.data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) {
      throw FirebaseFunctionsException(code: 'internal', message: 'No se pudo crear/leer el chat');
    }

    return chatId;
  }

  Future<void> sendMessage({String? schoolId, required String chatId, required String text}) async {
    final callable = _functions.httpsCallable('sendMessage');
    await callable.call<Map<String, dynamic>>({
      if (schoolId != null && schoolId.trim().isNotEmpty) 'schoolId': schoolId.trim(),
      'chatId': chatId,
      'text': text,
    });
  }

  Future<void> markChatRead({String? schoolId, required String chatId}) async {
    final callable = _functions.httpsCallable('markChatRead');
    await callable.call<Map<String, dynamic>>({
      if (schoolId != null && schoolId.trim().isNotEmpty) 'schoolId': schoolId.trim(),
      'chatId': chatId,
    });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService(FirebaseFunctions.instance));
