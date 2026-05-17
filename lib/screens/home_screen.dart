import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;

  final Color themeBg = const Color(0xFFFFFFFF);
  final Color coffeeBrown = const Color(0xFF53161D);

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  // --- POST SUBMISSION LOGIC ---
  void _createNewPost(String username) async {
    if (_postController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'authorId': widget.userId,
        'username': username,
        'text': _postController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likedBy': [],
        'isRepost': false,
        'parentId': null,
      });

      _postController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post shared successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating post: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // --- ACTIONS LOGIC ---
  void _toggleLike(String postId, List likedBy) async {
    if (likedBy.contains(widget.userId)) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likedBy': FieldValue.arrayRemove([widget.userId])
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likedBy': FieldValue.arrayUnion([widget.userId])
      });
    }
  }

  void _toggleRepost(Map<String, dynamic> post) async {
    try {
      var existing = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: widget.userId)
          .where('text', isEqualTo: post['text'])
          .where('isRepost', isEqualTo: true)
          .get();

      if (existing.docs.isNotEmpty) {
        String existingDocId = existing.docs.first.id;
        await FirebaseFirestore.instance.collection('posts').doc(existingDocId).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('posts').add({
          'text': post['text'],
          'authorId': widget.userId,
          'originalAuthorId': post['originalAuthorId'] ?? post['authorId'] ?? '',
          'username': post['username'] ?? 'user',
          'isRepost': true,
          'createdAt': FieldValue.serverTimestamp(),
          'likedBy': [],
          'parentId': null,
        });
      }
    } catch (e) {
      debugPrint("Error toggling repost: $e");
    }
  }

  void _showCommentDialog(String parentPostId, String originalText) {
    TextEditingController replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Reply", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: TextField(
            controller: replyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "Write a comment...")
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
            onPressed: () async {
              if (replyCtrl.text.trim().isEmpty) return;
              var myDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
              String myUsername = (myDoc.data() as Map<String, dynamic>?)?['username'] ?? 'user';

              await FirebaseFirestore.instance.collection('posts').add({
                'text': replyCtrl.text.trim(),
                'authorId': widget.userId,
                'username': myUsername,
                'isRepost': false,
                'createdAt': FieldValue.serverTimestamp(),
                'likedBy': [],
                'parentId': parentPostId,
              });

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Post", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        title: const Text("Delete Post?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Scaffold(
            backgroundColor: themeBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        String myUsername = userData['username'] ?? 'User';
        String myProfilePic = userData['profilePic'] ?? '';
        List friendsList = userData['following_list'] ?? [];

        Set<String> allowedUserIds = {widget.userId};
        for (var fId in friendsList) {
          if (fId is String && fId.isNotEmpty) {
            allowedUserIds.add(fId);
          }
        }

        return Scaffold(
          backgroundColor: themeBg,
          appBar: AppBar(
            backgroundColor: themeBg,
            elevation: 0,
            centerTitle: false,
            title: Padding(
              padding: const EdgeInsets.only(left: 4, top: 10),
              child: Text(
                "Home Feed",
                style: TextStyle(
                    color: coffeeBrown,
                    fontWeight: FontWeight.w900, // 👈 FIXED: Changed from .black to .w900
                    fontSize: 24,
                    letterSpacing: -0.5
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // --- THEMED CELESTIAL "WHAT'S ON YOUR MIND" CARD COMPONENT ---
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: coffeeBrown.withOpacity(0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: coffeeBrown.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: coffeeBrown.withOpacity(0.1),
                          backgroundImage: myProfilePic.isNotEmpty ? NetworkImage(myProfilePic) : null,
                          child: myProfilePic.isEmpty
                              ? Icon(Icons.person, color: coffeeBrown, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _postController,
                            maxLines: null,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                            decoration: InputDecoration(
                              hintText: "What's on your mind, @$myUsername?",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notes, size: 14, color: coffeeBrown.withOpacity(0.4)),
                            const SizedBox(width: 6),
                            Text(
                              "Share a thought...",
                              style: TextStyle(color: Colors.grey[400], fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: coffeeBrown,
                            foregroundColor: themeBg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          ),
                          onPressed: _isPosting ? null : () => _createNewPost(myUsername),
                          child: _isPosting
                              ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text(
                            "Post",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // DYNAMIC TIMELINE FEED STREAM
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').snapshots(),
                  builder: (context, feedSnapshot) {
                    if (feedSnapshot.hasError) {
                      return Center(child: Text("Error fetching feed: ${feedSnapshot.error}"));
                    }
                    if (!feedSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<QueryDocumentSnapshot> allDocs = feedSnapshot.data!.docs;

                    Set<String> myRepostedTexts = allDocs.where((doc) {
                      var postData = doc.data() as Map<String, dynamic>;
                      return postData['authorId'] == widget.userId &&
                          postData['isRepost'] == true;
                    }).map((doc) => (doc.data() as Map<String, dynamic>)['text']?.toString() ?? '').toSet();

                    var timelinePosts = allDocs.where((doc) {
                      var postData = doc.data() as Map<String, dynamic>;
                      String authorId = postData['authorId'] ?? '';
                      String postText = postData['text'] ?? '';
                      bool isRepost = postData['isRepost'] ?? false;
                      bool isRootPost = !postData.containsKey('parentId') || postData['parentId'] == null;

                      if (!isRootPost || !allowedUserIds.contains(authorId)) return false;

                      if (authorId == widget.userId && !isRepost && myRepostedTexts.contains(postText)) {
                        return false;
                      }

                      return true;
                    }).toList();

                    timelinePosts.sort((a, b) {
                      var dataA = a.data() as Map<String, dynamic>;
                      var dataB = b.data() as Map<String, dynamic>;

                      Timestamp timeA = dataA['createdAt'] as Timestamp? ?? Timestamp.now();
                      Timestamp timeB = dataB['createdAt'] as Timestamp? ?? Timestamp.now();

                      return timeB.compareTo(timeA);
                    });

                    if (timelinePosts.isEmpty) {
                      return Center(
                        child: Text(
                          "No posts to display.\nShare something or follow friends!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], height: 1.5, fontSize: 13),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: timelinePosts.length,
                      itemBuilder: (context, index) {
                        var rootDoc = timelinePosts[index];
                        var rootData = rootDoc.data() as Map<String, dynamic>;
                        String rootId = rootDoc.id;

                        var children = allDocs.where((d) => (d.data() as Map)['parentId'] == rootId).toList();
                        children.sort((a, b) => ((a.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now())
                            .compareTo((b.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now()));

                        return Column(
                          children: [
                            _buildPostCard(rootData, rootId, userData, isComment: false),
                            ...children.map((c) => _buildPostCard(c.data() as Map<String, dynamic>, c.id, userData, isComment: true)),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, String postId, Map<String, dynamic> userData, {required bool isComment}) {
    List likedBy = post['likedBy'] ?? [];
    DateTime dt = (post['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();
    String authorId = post['authorId'] ?? '';
    bool isMyPost = authorId == widget.userId;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: widget.userId)
          .where('text', isEqualTo: post['text'])
          .where('isRepost', isEqualTo: true)
          .snapshots(),
      builder: (context, repostSnap) {
        bool iHaveReposted = repostSnap.hasData && repostSnap.data!.docs.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(left: isComment ? 40 : 16, right: 16, top: 10, bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- LEFT SIDE: AVATAR AND THREAD CONNECTOR LINE ---
                Column(
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(authorId).get(),
                      builder: (context, uSnap) {
                        String pPic = '';
                        if (uSnap.hasData && uSnap.data!.exists) {
                          pPic = (uSnap.data!.data() as Map<String, dynamic>)['profilePic'] ?? '';
                        }
                        return CircleAvatar(
                          radius: 18,
                          backgroundColor: coffeeBrown.withOpacity(0.1),
                          backgroundImage: pPic.isNotEmpty ? NetworkImage(pPic) : null,
                          child: pPic.isEmpty ? Icon(Icons.person, color: coffeeBrown, size: 18) : null,
                        );
                      },
                    ),
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isComment ? Colors.transparent : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // --- RIGHT SIDE: CONTENT FRAME ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc((post['isRepost'] == true && post['originalAuthorId'] != null && post['originalAuthorId'].toString().isNotEmpty)
                                  ? post['originalAuthorId']
                                  : authorId)
                                  .get(),
                              builder: (context, userSnap) {
                                String currentName = post['username'] ?? 'user';
                                if (userSnap.hasData && userSnap.data!.exists) {
                                  currentName = (userSnap.data!.data() as Map<String, dynamic>)['username'] ?? currentName;
                                }
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "@$currentName",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    if (post['isRepost'] == true) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.repeat, size: 12, color: Colors.grey[500]),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(dt),
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Post Content Text String
                      Text(
                        post['text'] ?? '',
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                      ),
                      const SizedBox(height: 12),

                      // Action Row Elements
                      Row(
                        children: [
                          _actionIcon(
                            likedBy.contains(widget.userId) ? Icons.favorite : Icons.favorite_border,
                            likedBy.isNotEmpty ? "${likedBy.length}" : "",
                            likedBy.contains(widget.userId) ? Colors.red : coffeeBrown,
                                () => _toggleLike(postId, likedBy),
                          ),
                          const SizedBox(width: 16),
                          _actionIcon(
                            Icons.chat_bubble_outline,
                            "",
                            coffeeBrown,
                                () => _showCommentDialog(postId, post['text'] ?? ""),
                          ),
                          const SizedBox(width: 16),
                          if (!isComment)
                            _actionIcon(
                              Icons.repeat,
                              "",
                              iHaveReposted ? Colors.green : coffeeBrown,
                                  () => _toggleRepost(post),
                            ),
                          const Spacer(),
                          if (isMyPost)
                            InkWell(
                              onTap: () => _confirmDelete(postId),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.more_horiz, size: 18, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}