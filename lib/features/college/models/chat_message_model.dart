// ============================================================
// FILE: lib/features/college/models/chat_message_model.dart
// Real Firestore path: colleges/{collegeId}/chat/{messageId}
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType { text, quiz, tournament }

class ChatMessage {
  final String id;
  final String uid;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final ChatMessageType type;

  /// quizId if type == quiz, tournamentId if type == tournament
  final String? refId;
  final String? refTitle;

  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.uid,
    required this.senderName,
    this.senderPhotoUrl = '',
    required this.text,
    this.type = ChatMessageType.text,
    this.refId,
    this.refTitle,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      uid: d['uid'] ?? '',
      senderName: d['senderName'] ?? 'User',
      senderPhotoUrl: d['senderPhotoUrl'] ?? '',
      text: d['text'] ?? '',
      type: _parseType(d['type']),
      refId: d['refId'],
      refTitle: d['refTitle'],
      timestamp:
          (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static ChatMessageType _parseType(dynamic v) {
    switch (v) {
      case 'quiz':
        return ChatMessageType.quiz;
      case 'tournament':
        return ChatMessageType.tournament;
      default:
        return ChatMessageType.text;
    }
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'text': text,
        'type': type.name,
        'refId': refId,
        'refTitle': refTitle,
        'timestamp': FieldValue.serverTimestamp(),
      };
}