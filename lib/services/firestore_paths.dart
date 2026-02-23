class FirestorePaths {
  const FirestorePaths._();

  static String school(String schoolId) => 'schools/$schoolId';
  static String user(String schoolId, String uid) => 'schools/$schoolId/users/$uid';
  static String posts(String schoolId) => 'schools/$schoolId/posts';
  static String events(String schoolId) => 'schools/$schoolId/events';
  static String chats(String schoolId) => 'schools/$schoolId/chats';
  static String chatMessages(String schoolId, String chatId) => 'schools/$schoolId/chats/$chatId/messages';
}
