import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  final Color themeBg = const Color(0xFFFEFAEF);
  final Color coffeeBrown = const Color(0xFF53161D);

  // --- ACTIONS ---

  void _deleteNotification(BuildContext context, String notifId, Map<String, dynamic> data) {
    FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Notification deleted"),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "UNDO",
          textColor: Colors.yellow,
          onPressed: () {
            FirebaseFirestore.instance.collection('notifications').doc(notifId).set(data);
          },
        ),
      ),
    );
  }

  void _acceptFriend(BuildContext context, String notifId, String senderId, String senderName) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'following_list': FieldValue.arrayUnion([senderId])
    });
    await FirebaseFirestore.instance.collection('users').doc(senderId).update({
      'following_list': FieldValue.arrayUnion([userId])
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'friend_accepted',
      'message': 'accepted your request. You are now friends!',
      'senderId': userId,
      'receiverId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Accepted $senderName's request")));
    }
  }

  void _declineFriend(BuildContext context, String notifId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request declined")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: themeBg,
        elevation: 0,
        title: Text("Notifications", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No notifications yet."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String type = data['type'] ?? '';
              String senderId = data['senderId'] ?? '';
              String rawMessage = data['message'] ?? '';
              String postContent = data['postContent'] ?? '';

              // FETCH LATEST SENDER INFO (Username, Location, Gender)
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, userSnap) {
                  Map<String, dynamic> senderInfo = {};
                  if (userSnap.hasData && userSnap.data!.exists) {
                    senderInfo = userSnap.data!.data() as Map<String, dynamic>;
                  }

                  String currentUsername = senderInfo['username'] ?? 'User';
                  String currentLoc = senderInfo['location'] ?? 'Earth';
                  String currentGender = senderInfo['gender'] ?? 'None';

                  // If message contains the username directly (like profile note sharing), remove it
                  // so we can dynamically format the username uniformly across all notifications.
                  String displayActionText = rawMessage;
                  if (displayActionText.toLowerCase().startsWith(currentUsername.toLowerCase())) {
                    displayActionText = displayActionText.substring(currentUsername.length).trim();
                  }

                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) => _deleteNotification(context, doc.id, data),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: coffeeBrown.withOpacity(0.1),
                                child: Icon(_getIcon(type), color: coffeeBrown, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("@$currentUsername", style: TextStyle(fontWeight: FontWeight.bold, color: coffeeBrown)),
                                    Text("$currentGender • $currentLoc", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                onPressed: () => _deleteNotification(context, doc.id, data),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // UNIFORM UI AND FONT TREATMENT FOR ALL NOTIFICATIONS
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black, fontSize: 14),
                              children: [
                                TextSpan(text: currentUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const TextSpan(text: " "),
                                TextSpan(text: displayActionText),
                              ],
                            ),
                          ),

                          if (postContent.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: themeBg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: coffeeBrown.withOpacity(0.1)),
                              ),
                              child: Text(
                                "\"$postContent\"",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: coffeeBrown.withOpacity(0.8)),
                              ),
                            ),

                          if (type == 'friend_request')
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: () => _acceptFriend(context, doc.id, senderId, currentUsername),
                                      child: const Text("Confirm", style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(side: BorderSide(color: coffeeBrown), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: () => _declineFriend(context, doc.id),
                                      child: Text("Decline", style: TextStyle(color: coffeeBrown)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(_formatTime(data['createdAt']), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    return DateFormat('MMM d, yyyy • h:mm a').format((timestamp as Timestamp).toDate());
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.chat_bubble;
      case 'repost': return Icons.repeat;
      case 'friend_request': return Icons.person_add;
      case 'friend_accepted': return Icons.handshake;
      case 'note': return Icons.sticky_note_2_rounded;
      default: return Icons.notifications;
    }
  }
}