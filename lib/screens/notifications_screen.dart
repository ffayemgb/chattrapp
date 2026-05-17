import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  final Color themeBg = const Color(0xFFFFFFFF);
  final Color coffeeBrown = const Color(0xFF53161D);

  // --- ACTIONS ---

  void _deleteNotification(BuildContext context, String notifId, Map<String, dynamic> data) {
    FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: coffeeBrown,
        content: const Text("Notification deleted", style: TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "UNDO",
          textColor: const Color(0xFFFEFAEF),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: coffeeBrown,
          content: Text("Accepted $senderName's request", style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _declineFriend(BuildContext context, String notifId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: coffeeBrown,
          content: const Text("Request declined", style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: themeBg,
        elevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 4, top: 10),
          child: Text(
            "Notifications",
            style: TextStyle(
              color: coffeeBrown,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
        ),
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
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 48, color: coffeeBrown.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    "No notifications yet.",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String type = data['type'] ?? '';
              String senderId = data['senderId'] ?? '';
              String rawMessage = data['message'] ?? '';
              String postContent = data['postContent'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, userSnap) {
                  Map<String, dynamic> senderInfo = {};
                  if (userSnap.hasData && userSnap.data!.exists) {
                    senderInfo = userSnap.data!.data() as Map<String, dynamic>;
                  }

                  String currentUsername = senderInfo['username'] ?? 'user';
                  String currentLoc = senderInfo['location'] ?? 'Earth';
                  String currentGender = senderInfo['gender'] ?? 'None';
                  String profilePic = senderInfo['profilePic'] ?? '';

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
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: coffeeBrown.withOpacity(0.9),
                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: coffeeBrown.withOpacity(0.06), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: coffeeBrown.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: coffeeBrown.withOpacity(0.1),
                                    backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                                    child: profilePic.isEmpty
                                        ? Icon(Icons.person, color: coffeeBrown, size: 20)
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: coffeeBrown,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Icon(_getIcon(type), color: Colors.white, size: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "@$currentUsername",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: coffeeBrown, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "$currentGender • $currentLoc",
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded, size: 16, color: Colors.grey[400]),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteNotification(context, doc.id, data),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Notification Text Content
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.3),
                              children: [
                                TextSpan(
                                  text: currentUsername,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: coffeeBrown),
                                ),
                                const TextSpan(text: " "),
                                TextSpan(text: displayActionText),
                              ],
                            ),
                          ),

                          // Post Box Snippet Container
                          if (postContent.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: coffeeBrown.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: coffeeBrown.withOpacity(0.06)),
                              ),
                              child: Text(
                                "\"$postContent\"",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: coffeeBrown.withOpacity(0.85), height: 1.3),
                              ),
                            ),

                          // Friend Request Action Buttons
                          if (type == 'friend_request')
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: coffeeBrown,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: () => _acceptFriend(context, doc.id, senderId, currentUsername),
                                      child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: coffeeBrown.withOpacity(0.3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: () => _declineFriend(context, doc.id),
                                      child: Text("Decline", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              _formatTime(data['createdAt']),
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
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
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'repost': return Icons.repeat_rounded;
      case 'friend_request': return Icons.person_add_alt_1_rounded;
      case 'friend_accepted': return Icons.handshake_rounded;
      case 'note': return Icons.sticky_note_2_rounded;
      default: return Icons.notifications_rounded;
    }
  }
}