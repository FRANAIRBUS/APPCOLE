import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({required this.senderUid, required this.text, required this.createdAt});

  final String senderUid;
  final String text;
  final Timestamp createdAt;

  Map<String, dynamic> toJson() => {
        'senderUid': senderUid,
        'text': text,
        'createdAt': createdAt,
      };
}
