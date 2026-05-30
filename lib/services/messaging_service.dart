import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Live stream of messages for a chat, ordered oldest-first.
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // Write a new message document. Uses server timestamp so ordering is exact.
  // After a successful write, fires a notification to recipientId (best-effort:
  // notification failure is isolated so it never fails the message send).
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String recipientId,
    required String text,
  }) async {
    final messageId = const Uuid().v4();
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Message write succeeded. Now write a notification to the recipient.
    // Any failure here is swallowed so it never affects the message send.
    try {
      final notifId = const Uuid().v4();
      final body = text.length > 100 ? '${text.substring(0, 100)}…' : text;
      await _firestore
          .collection('notifications')
          .doc(recipientId)
          .collection('items')
          .doc(notifId)
          .set({
        'title': 'New message',
        'body': body,
        'type': 'message',
        'chatId': chatId,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('sendMessage notification write ERROR: $e');
    }
  }
}
