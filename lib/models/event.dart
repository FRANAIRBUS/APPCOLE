import 'package:cloud_firestore/cloud_firestore.dart';

class ColeEvent {
  const ColeEvent({
    required this.title,
    required this.description,
    required this.dateTime,
    required this.place,
    required this.organizerUid,
  });

  final String title;
  final String description;
  final Timestamp dateTime;
  final String place;
  final String organizerUid;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'dateTime': dateTime,
        'place': place,
        'organizerUid': organizerUid,
      };
}
