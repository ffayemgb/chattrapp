import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_room_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String userId;
  const MessagesScreen({super.key, required this.userId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final Color themeBg = const Color(0xFFFEFAEF);
  final Color coffeeBrown = const Color(0xFF53161D);

  // Helper for relative timestamps (e.g., 2m, 1h)
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) return "${diff.inSeconds}s";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: themeBg,
        elevation: 0,
        title: Text("Messages",
            style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildNotesSection(), // The Messenger-style Notes area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading chats"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var chats = snapshot.data!.docs;

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 50, color: coffeeBrown.withOpacity(0.2)),
                        const SizedBox(height: 10),
                        Text("No conversations yet", style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  );
                }

                chats.sort((a, b) {
                  var aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                  var bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    var chat = chats[index].data() as Map<String, dynamic>;
                    String chatRoomId = chats[index].id;
                    List participants = chat['participants'] ?? [];

                    String otherUserId = participants.firstWhere(
                            (id) => id != widget.userId,
                        orElse: () => ""
                    );

                    if (otherUserId.isEmpty) return const SizedBox();

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        var otherUser = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                        String otherName = otherUser['username'] ?? 'user';

                        bool iSentLast = chat['lastSenderId'] == widget.userId;
                        String displayMsg = chat['lastMessage'] ?? "";

                        if (displayMsg.isEmpty) {
                          displayMsg = "Started a conversation";
                        } else {
                          displayMsg = iSentLast ? "You: $displayMsg" : displayMsg;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: coffeeBrown.withOpacity(0.1),
                            backgroundImage: (otherUser['profilePic'] != null && otherUser['profilePic'] != "")
                                ? NetworkImage(otherUser['profilePic']) : null,
                            child: (otherUser['profilePic'] == null || otherUser['profilePic'] == "")
                                ? Icon(Icons.person, color: coffeeBrown) : null,
                          ),
                          title: Text("@$otherName", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(displayMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            chat['lastMessageTime'] != null
                                ? DateFormat('h:mm a').format((chat['lastMessageTime'] as Timestamp).toDate())
                                : "now",
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomScreen(
                                  chatRoomId: chatRoomId,
                                  currentUserId: widget.userId,
                                  otherUserName: otherName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: coffeeBrown,
        elevation: 4,
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
        onPressed: () => _showNewChatDialog(),
      ),
    );
  }
  Widget _buildNotesSection() {
    return Container(
      height: 130,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: StreamBuilder<DocumentSnapshot>(
        // 1. Get your own data to see who you are following
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          var myData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          List myFollowing = myData['following_list'] ?? [];

          if (myFollowing.isEmpty) return const SizedBox();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: myFollowing.length,
            itemBuilder: (context, index) {
              String friendId = myFollowing[index];

              // 2. Fetch the friend's User data (to check mutual and get Profile Pic)
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                builder: (context, friendSnap) {
                  if (!friendSnap.hasData) return const SizedBox();
                  var friendData = friendSnap.data!.data() as Map<String, dynamic>? ?? {};

                  // MUTUAL FRIEND CHECK
                  List theirFollowing = friendData['following_list'] ?? [];
                  bool isMutual = theirFollowing.contains(widget.userId);
                  if (!isMutual) return const SizedBox();

                  // 3. Fetch the note from the 'notes' collection (matching your Profile logic)
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('notes').doc(friendId).snapshots(),
                    builder: (context, noteSnap) {
                      if (!noteSnap.hasData) return const SizedBox();
                      var noteData = noteSnap.data!.data() as Map<String, dynamic>?;

                      // Check if note exists and is less than 24 hours old
                      bool hasActiveNote = false;
                      String noteText = "";
                      Timestamp? noteTime;

                      if (noteData != null && noteData['createdAt'] != null) {
                        noteTime = noteData['createdAt'] as Timestamp;
                        if (DateTime.now().difference(noteTime.toDate()).inHours < 24) {
                          hasActiveNote = true;
                          noteText = noteData['text'] ?? "";
                        }
                      }

                      // Only show in the bar if they actually have a valid note
                      if (!hasActiveNote) return const SizedBox();

                      return GestureDetector(
                        onTap: () => _startConversation(friendId, friendData['username'] ?? 'user'),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 15),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: coffeeBrown.withOpacity(0.1),
                                    backgroundImage: (friendData['profilePic'] != null && friendData['profilePic'] != "")
                                        ? NetworkImage(friendData['profilePic']) : null,
                                    child: (friendData['profilePic'] == null || friendData['profilePic'] == "")
                                        ? Icon(Icons.person, color: coffeeBrown) : null,
                                  ),
                                  // The Note Bubble
                                  Positioned(
                                    top: -12,
                                    left: -5,
                                    right: -5,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                        ),
                                        child: Text(
                                          noteText,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "@${friendData['username']}",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatTimestamp(noteTime),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
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
          );
        },
      ),
    );
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.only(top: 10),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              List friends = userData['following_list'] ?? [];

              if (friends.isEmpty) {
                return const Center(child: Text("Follow users to start chatting!"));
              }

              return Column(
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const Padding(padding: EdgeInsets.all(20), child: Text("New Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Expanded(
                    child: ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friends[index]).get(),
                          builder: (context, friendSnap) {
                            if (!friendSnap.hasData) return const SizedBox();
                            var friendData = friendSnap.data!.data() as Map<String, dynamic>? ?? {};
                            String name = friendData['username'] ?? 'user';
                            return ListTile(
                              leading: CircleAvatar(backgroundImage: (friendData['profilePic'] != null && friendData['profilePic'] != "") ? NetworkImage(friendData['profilePic']) : null),
                              title: Text("@$name"),
                              onTap: () { Navigator.pop(context); _startConversation(friends[index], name); },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _startConversation(String otherUserId, String otherName) async {
    List<String> ids = [widget.userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    var chatRoom = await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).get();
    if (!chatRoom.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatRoomScreen(
      chatRoomId: chatRoomId,
      currentUserId: widget.userId,
      otherUserName: otherName,
    )));
  }
}