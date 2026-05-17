import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserPreviewScreen extends StatefulWidget {
  final String targetUserId;
  final String currentUserId;

  const UserPreviewScreen({super.key, required this.targetUserId, required this.currentUserId});

  @override
  State<UserPreviewScreen> createState() => _UserPreviewScreenState();
}

class _UserPreviewScreenState extends State<UserPreviewScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final Color themeBg = const Color(0xFFFEFAEF);
  final Color coffeeBrown = const Color(0xFF53161D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- TIME FORMATTER ---
  String _getNoteTime(Timestamp? timestamp) {
    if (timestamp == null) return "0s";
    final now = DateTime.now();
    final diff = now.difference(timestamp.toDate());

    if (diff.inSeconds < 60) return "${diff.inSeconds}s";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "";
  }

  // --- ACTIONS LOGIC ---

  void _toggleLike(String postId, Map<String, dynamic> postData) async {
    List likedBy = List.from(postData['likedBy'] ?? []);
    bool isLiked = likedBy.contains(widget.currentUserId);

    if (isLiked) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likedBy': FieldValue.arrayRemove([widget.currentUserId])
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likedBy': FieldValue.arrayUnion([widget.currentUserId])
      });
      _sendNotification('like', "liked your post", widget.targetUserId, postText: postData['text']);
    }
  }

  void _sendNotification(String type, String message, String receiverId, {String? postText}) async {
    if (widget.currentUserId == receiverId) return;

    try {
      var myDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
      if (!myDoc.exists) return;

      var myData = myDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': type,
        'message': message,
        'senderId': widget.currentUserId,
        'receiverId': receiverId,
        'senderName': myData['username'] ?? 'Unknown User',
        'senderLoc': myData['location'] ?? 'Earth',
        'senderGender': myData['gender'] ?? 'Not specified',
        'senderBio': myData['bio'] ?? '',
        'postContent': postText ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  void _toggleRepost(Map<String, dynamic> post) async {
    var existing = await FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', isEqualTo: widget.currentUserId)
        .where('text', isEqualTo: post['text'])
        .where('isRepost', isEqualTo: true)
        .get();

    bool alreadyReposted = existing.docs.isNotEmpty;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(alreadyReposted ? "Remove Repost?" : "Repost?",
            style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: Text(alreadyReposted
            ? "Are you sure you want to remove this repost?"
            : "Are you sure you want to repost this to your feed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("No", style: TextStyle(color: coffeeBrown))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (alreadyReposted) {
                for (var doc in existing.docs) {
                  await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
                }
              } else {
                _sendNotification('repost', " reposted your thought", widget.targetUserId);
                await FirebaseFirestore.instance.collection('posts').add({
                  'text': post['text'],
                  'authorId': widget.currentUserId,
                  'isRepost': true,
                  'createdAt': FieldValue.serverTimestamp(),
                  'likedBy': [],
                });
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(String parentPostId, String originalText) {
    TextEditingController postCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Reply", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: TextField(controller: postCtrl, maxLines: 3, decoration: const InputDecoration(hintText: "Write a comment...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
            onPressed: () async {
              if (postCtrl.text.trim().isEmpty) return;
              if (!context.mounted) return;
              Navigator.pop(context);

              _sendNotification('comment', "replied to your post", widget.targetUserId, postText: originalText);

              await FirebaseFirestore.instance.collection('posts').add({
                'text': postCtrl.text.trim(),
                'authorId': widget.currentUserId,
                'isRepost': false,
                'createdAt': FieldValue.serverTimestamp(),
                'likedBy': [],
                'parentId': parentPostId,
              });
            },
            child: const Text("Post", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var userData = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: themeBg,
          appBar: AppBar(backgroundColor: themeBg, elevation: 0, iconTheme: IconThemeData(color: coffeeBrown)),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildNotesSection(),
                      _buildHeader(userData),
                      const SizedBox(height: 25),
                      _buildStats(),
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverDelegate(TabBar(
                  controller: _tabController,
                  labelColor: coffeeBrown,
                  indicatorColor: coffeeBrown,
                  tabs: const [Tab(text: "Posts"), Tab(text: "Likes"), Tab(text: "Reposts")],
                ), themeBg),
              )
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildFeed(FirebaseFirestore.instance.collection('posts')
                    .where('authorId', isEqualTo: widget.targetUserId)
                    .where('isRepost', isEqualTo: false)
                    .where('parentId', isNull: true)),
                _buildFeed(FirebaseFirestore.instance.collection('posts')
                    .where('likedBy', arrayContains: widget.targetUserId)),
                _buildFeed(FirebaseFirestore.instance.collection('posts')
                    .where('authorId', isEqualTo: widget.targetUserId)
                    .where('isRepost', isEqualTo: true)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeed(Query query) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        List<QueryDocumentSnapshot> mainDocs = snapshot.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').snapshots(),
          builder: (context, allPostsSnap) {
            if (!allPostsSnap.hasData) return const SizedBox();
            List<QueryDocumentSnapshot> globalDocs = allPostsSnap.data!.docs;

            mainDocs.sort((a, b) {
              Timestamp tA = (a.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now();
              Timestamp tB = (b.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now();
              return tB.compareTo(tA);
            });

            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: mainDocs.length,
              itemBuilder: (context, index) {
                var rootDoc = mainDocs[index];
                var rootData = rootDoc.data() as Map<String, dynamic>;
                var children = globalDocs.where((d) => (d.data() as Map)['parentId'] == rootDoc.id).toList();

                children.sort((a, b) => ((a.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now())
                    .compareTo((b.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now()));

                return Column(
                  children: [
                    _postCard(rootData, rootDoc.id, isComment: false),
                    ...children.map((c) => _postCard(c.data() as Map<String, dynamic>, c.id, isComment: true)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _postCard(Map<String, dynamic> post, String postId, {required bool isComment}) {
    List likedBy = post['likedBy'] ?? [];
    String authorId = post['authorId'] ?? '';
    bool isMyPost = authorId == widget.currentUserId;

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts')
            .where('authorId', isEqualTo: widget.currentUserId)
            .where('text', isEqualTo: post['text'])
            .where('isRepost', isEqualTo: true)
            .snapshots(),
        builder: (context, repostSnap) {
          bool iHaveReposted = repostSnap.hasData && repostSnap.data!.docs.isNotEmpty;

          return Container(
            margin: EdgeInsets.only(left: isComment ? 40 : 15, right: 15, top: 5, bottom: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComment ? Colors.grey[50] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(authorId).get(),
                      builder: (context, userSnap) {
                        String currentName = post['username'] ?? 'user';
                        if (userSnap.hasData && userSnap.data!.exists) {
                          currentName = (userSnap.data!.data() as Map<String, dynamic>)['username'] ?? currentName;
                        }
                        return Text("@$currentName",
                            style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 13));
                      },
                    ),
                    Text(DateFormat('MMM d, yyyy • h:mm a').format((post['createdAt'] as Timestamp? ?? Timestamp.now()).toDate()),
                        style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(post['text'] ?? ""),
                const Divider(height: 20),
                Row(
                  children: [
                    _actionIcon(
                        likedBy.contains(widget.currentUserId) ? Icons.favorite : Icons.favorite_border,
                        "${likedBy.length}",
                        likedBy.contains(widget.currentUserId) ? Colors.red : coffeeBrown,
                            () => _toggleLike(postId, post)
                    ),
                    const SizedBox(width: 20),

                    _actionIcon(
                        Icons.chat_bubble_outline,
                        "Reply",
                        coffeeBrown,
                            () => _showCommentDialog(postId, post['text'] ?? "")
                    ),

                    const SizedBox(width: 20),

                    if (!isComment)
                      _actionIcon(
                          Icons.repeat,
                          iHaveReposted ? "Reposted" : "Repost",
                          iHaveReposted ? Colors.green : Colors.blue,
                              () => _toggleRepost(post)
                      ),

                    const Spacer(),
                    if (isMyPost)
                      IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                          onPressed: () => _confirmDelete(postId)
                      ),
                  ],
                )
              ],
            ),
          );
        }
    );
  }

  void _confirmDelete(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        title: const Text("Delete?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
            if (!mounted) return;
            Navigator.pop(context);
          }, child: const Text("Yes", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, color: color))]));
  }

  Widget _buildNotesSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('notes').doc(widget.targetUserId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox(height: 20);

        var noteData = snap.data!.data() as Map<String, dynamic>;
        Timestamp? createdAt = noteData['createdAt'] as Timestamp?;

        if (createdAt != null) {
          final diff = DateTime.now().difference(createdAt.toDate());
          if (diff.inHours >= 24) {
            return const SizedBox(height: 20);
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(noteData['text'] ?? "", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic))),
              const SizedBox(width: 8),
              Text(_getNoteTime(createdAt), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> userData) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: coffeeBrown,
          backgroundImage: (userData['profilePic'] != null && userData['profilePic'] != "") ? NetworkImage(userData['profilePic']) : null,
          child: (userData['profilePic'] == null || userData['profilePic'] == "") ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
        ),
        const SizedBox(height: 10),
        Text("@${userData['username']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 14, color: coffeeBrown),
            Flexible(
              child: Text(" ${userData['location'] ?? 'Earth'}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13)
              ),
            ),
            const SizedBox(width: 15),
            Icon(Icons.person, size: 14, color: coffeeBrown),
            Text(" ${userData['gender'] ?? 'Secret'}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        Text(userData['bio'] ?? "No bio yet", textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: _statItem(FirebaseFirestore.instance.collection('posts').where('authorId', isEqualTo: widget.targetUserId).where('isRepost', isEqualTo: false).where('parentId', isNull: true), "Posts")),
        Expanded(child: _statItem(FirebaseFirestore.instance.collection('posts').where('authorId', isEqualTo: widget.targetUserId).where('isRepost', isEqualTo: true), "Reposts")),
        Expanded(child: _friendCount()),
      ],
    );
  }

  Widget _statItem(Query query, String label) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) => Column(children: [
        Text(snap.hasData ? snap.data!.docs.length.toString() : "0", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: coffeeBrown)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  Widget _friendCount() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
      builder: (context, snap) {
        int count = 0;
        if (snap.hasData && snap.data!.exists) {
          var data = snap.data!.data() as Map<String, dynamic>;
          if (data.containsKey('following_list') && data['following_list'] != null) {
            count = (data['following_list'] as List).length;
          }
        }
        return Column(
          children: [
            Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: coffeeBrown)),
            const Text("Friends", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        );
      },
    );
  }

  void _cancelRequest() async {
    var docs = await FirebaseFirestore.instance.collection('notifications')
        .where('senderId', isEqualTo: widget.currentUserId)
        .where('receiverId', isEqualTo: widget.targetUserId)
        .where('type', isEqualTo: 'friend_request')
        .get();

    for (var doc in docs.docs) {
      await doc.reference.delete();
    }
  }

  void _showUnfriendDialog(String targetId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Unfriend?", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to remove this person from your friends?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: coffeeBrown))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).update({
                'following_list': FieldValue.arrayRemove([targetId])
              });
              await FirebaseFirestore.instance.collection('users').doc(targetId).update({
                'following_list': FieldValue.arrayRemove([widget.currentUserId])
              });
            },
            child: const Text("Unfriend", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications')
          .where('senderId', isEqualTo: widget.currentUserId)
          .where('receiverId', isEqualTo: widget.targetUserId)
          .where('type', isEqualTo: 'friend_request').snapshots(),
      builder: (context, requestSnap) {
        bool hasSentRequest = requestSnap.hasData && requestSnap.data!.docs.isNotEmpty;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox();

            var data = userSnap.data!.data() as Map<String, dynamic>;
            List friends = data['following_list'] ?? [];
            bool isFriend = friends.contains(widget.targetUserId);

            String buttonText = isFriend ? "Friends" : (hasSentRequest ? "Cancel" : "Add Friend");

            return Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFriend ? coffeeBrown : (hasSentRequest ? Colors.grey[400] : coffeeBrown),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (isFriend) {
                        _showUnfriendDialog(widget.targetUserId);
                      } else if (hasSentRequest) {
                        _cancelRequest();
                      } else {
                        _sendNotification('friend_request', "sent you a friend request", widget.targetUserId);
                      }
                    },
                    child: Text(buttonText, style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: coffeeBrown),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () { /* Message logic */ },
                    child: Text("Message", style: TextStyle(color: coffeeBrown)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SliverDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar; final Color bg; _SliverDelegate(this.tabBar, this.bg);
  @override double get minExtent => 48; @override double get maxExtent => 48;
  @override Widget build(context, offset, overlaps) => Container(color: bg, child: tabBar);
  @override bool shouldRebuild(covariant old) => false;
}