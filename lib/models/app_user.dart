import 'package:cloud_firestore/cloud_firestore.dart';

class ChildProfile {
  const ChildProfile({required this.name, required this.age, required this.classId});

  final String name;
  final int age;
  final String classId;

  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'classId': classId};

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        name: json['name'] as String,
        age: json['age'] as int,
        classId: json['classId'] as String,
      );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.children,
    required this.classIds,
    required this.createdAt,
    this.photoUrl,
    this.professional,
  });

  final String uid;
  final String displayName;
  final String role;
  final List<ChildProfile> children;
  final List<String> classIds;
  final String? photoUrl;
  final String? professional;
  final Timestamp createdAt;

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'role': role,
        'children': children.map((e) => e.toJson()).toList(),
        'classIds': classIds,
        'photoUrl': photoUrl,
        'professional': professional,
        'createdAt': createdAt,
      };
}
