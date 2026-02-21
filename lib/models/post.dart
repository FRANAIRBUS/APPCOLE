import 'package:cloud_firestore/cloud_firestore.dart';

class ColePost {
  const ColePost({
    required this.module,
    required this.type,
    required this.title,
    required this.body,
    required this.authorUid,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  final String module;
  final String type;
  final String title;
  final String body;
  final String authorUid;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final String status;

  Map<String, dynamic> toJson() => {
        'module': module,
        'type': type,
        'title': title,
        'body': body,
        'authorUid': authorUid,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'status': status,
      };
}
