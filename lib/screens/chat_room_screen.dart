import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String currentUserId;
  final String otherUserName;

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.currentUserId,
    required this.otherUserName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final Color coffeeBrown = const Color(0xFF53161D);
  final Color themeBg = const Color(0xFFFEFAEF);

  void _handleReaction(String messageId, String emoji) async {
    DocumentReference msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .doc(messageId);

    DocumentSnapshot doc = await msgRef.get();
    if (!doc.exists) return;

    Map<String, dynamic> reactions = {};
    var data = doc.data() as Map<String, dynamic>;
    if (data.containsKey('reactions') && data['reactions'] != null) {
      reactions = Map<String, dynamic>.from(data['reactions']);
    }

    if (reactions[widget.currentUserId] == emoji) {
      reactions.remove(widget.currentUserId);
    } else {
      reactions[widget.currentUserId] = emoji;
    }

    await msgRef.update({'reactions': reactions});
  }

  // Updated Popup to appear cleaner (using BottomSheet for that "behind/integrated" feel)
  void _showReactionMenu(BuildContext context, String messageId) {
    final List<String> emojis = ["❤️", "👍", "😂", "😮", "😢", "😡"];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((e) => GestureDetector(
            onTap: () {
              _handleReaction(messageId, e);
              Navigator.pop(context);
            },
            child: Text(e, style: const TextStyle(fontSize: 30)),
          )).toList(),
        ),
      ),
    );
  }

  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatRoomId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': widget.currentUserId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text("@${widget.otherUserName}",
            style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: coffeeBrown),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String msgId = docs[index].id;
                    bool isMe = data['senderId'] == widget.currentUserId;
                    Map reactions = data['reactions'] ?? {};

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              if (isMe) _reaxButton(msgId),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                                decoration: BoxDecoration(
                                  color: isMe ? coffeeBrown : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(isMe ? 15 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 15),
                                  ),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                                ),
                                child: Text(
                                  data['text'] ?? "",
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                                ),
                              ),
                              if (!isMe) _reaxButton(msgId),
                            ],
                          ),

                          // --- UPDATED REACTION UI (WITH COUNT) ---
                          if (reactions.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 4, right: isMe ? 5 : 0, left: !isMe ? 5 : 0),
                              child: Wrap(
                                spacing: 4,
                                children: reactions.values.toSet().map((emoji) {
                                  // Count how many people used this specific emoji
                                  int count = reactions.values.where((e) => e == emoji).length;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: Colors.grey.shade200),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(emoji.toString(), style: const TextStyle(fontSize: 12)),
                                        if (count > 1) ...[
                                          const SizedBox(width: 4),
                                          Text("$count", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: coffeeBrown)),
                                        ]
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _reaxButton(String msgId) {
    return IconButton(
      onPressed: () => _showReactionMenu(context, msgId),
      icon: Icon(Icons.add_reaction_outlined, size: 18, color: coffeeBrown.withOpacity(0.4)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: themeBg, borderRadius: BorderRadius.circular(25)),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Brew a message...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _sendMessage,
              icon: Icon(Icons.send_rounded, color: coffeeBrown),
            ),
          ],
        ),
      ),
    );
  }
}