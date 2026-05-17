import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_preview_screen.dart';

class SearchScreen extends StatefulWidget {
  final String currentUserId;
  const SearchScreen({super.key, required this.currentUserId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = "";
  final Color themeBg = const Color(0xFFFFFFFF);
  final Color coffeeBrown = const Color(0xFF53161D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: themeBg,
        elevation: 0,
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: coffeeBrown.withOpacity(0.2)),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                // Remove @ symbol automatically to match database records
                _searchQuery = value.toLowerCase().replaceAll('@', '').trim();
              });
            },
            decoration: InputDecoration(
              hintText: "Search users...",
              prefixIcon: Icon(Icons.search, color: coffeeBrown),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filter logic
          var users = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var username = (data['username'] ?? "").toString().toLowerCase();

            // 1. Never show yourself in the list
            if (doc.id == widget.currentUserId) return false;

            // 2. If search bar is empty, return true (shows all users)
            if (_searchQuery.isEmpty) return true;

            // 3. If typing, return true only if the username matches the query
            return username.contains(_searchQuery);
          }).toList();

          if (users.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty ? "No other users exist yet" : "No users found matching '@$_searchQuery'",
                style: TextStyle(color: coffeeBrown.withOpacity(0.5)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index].data() as Map<String, dynamic>;
              String userId = users[index].id;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserPreviewScreen(
                        targetUserId: userId,
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: coffeeBrown.withOpacity(0.1),
                        backgroundImage: (user['profilePic'] != null && user['profilePic'] != "")
                            ? NetworkImage(user['profilePic'])
                            : null,
                        child: (user['profilePic'] == null || user['profilePic'] == "")
                            ? Icon(Icons.person, color: coffeeBrown)
                            : null,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("@${user['username'] ?? 'user'}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(user['bio'] ?? "No bio yet",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: coffeeBrown),
                                Text(" ${user['location'] ?? 'Earth'}", style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 10),
                                Icon(Icons.person_pin, size: 12, color: coffeeBrown),
                                Text(" ${user['gender'] ?? 'Secret'}", style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _requestButton(userId),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _requestButton(String targetUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: widget.currentUserId)
          .where('receiverId', isEqualTo: targetUserId)
          .where('type', isEqualTo: 'friend_request')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasRequested = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const SizedBox();
            var myData = userSnap.data!.data() as Map<String, dynamic>;
            List friends = myData['following_list'] ?? [];
            bool isFriend = friends.contains(targetUserId);

            if (isFriend) {
              return Text("Friends",
                  style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 12));
            }

            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasRequested ? Colors.grey[300] : coffeeBrown,
                foregroundColor: hasRequested ? Colors.black87 : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(80, 36),
              ),
              onPressed: () => _toggleRequest(targetUserId, hasRequested),
              child: Text(hasRequested ? "Cancel" : "Add",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }

  void _toggleRequest(String targetId, bool hasRequested) async {
    if (hasRequested) {
      var docs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: widget.currentUserId)
          .where('receiverId', isEqualTo: targetId)
          .where('type', isEqualTo: 'friend_request')
          .get();
      for (var d in docs.docs) {
        await d.reference.delete();
      }
    } else {
      var myDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
      var myData = myDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'friend_request',
        'senderId': widget.currentUserId,
        'receiverId': targetId,
        'senderName': myData['username'],
        'senderBio': myData['bio'],
        'senderLoc': myData['location'],
        'senderGender': myData['gender'],
        'message': "sent you a friend request",
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}