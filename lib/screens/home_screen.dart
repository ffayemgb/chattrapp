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

  final Color themeBg = const Color(0xFFFEFAEF);
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
      // Look for an existing repost made by YOU for this specific post text
      var existing = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: widget.userId)
          .where('text', isEqualTo: post['text'])
          .where('isRepost', isEqualTo: true)
          .get();

      if (existing.docs.isNotEmpty) {
        // 🌟 IF ALREADY REPOSTED: Update the timestamp quietly to move it above the feed (No popup)
        String existingDocId = existing.docs.first.id;
        await FirebaseFirestore.instance.collection('posts').doc(existingDocId).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 🌟 IF NOT REPOSTED YET: Add it clean straight away (No popup)
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
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color))
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
            title: Text(
              "Home Feed",
              style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.w900, fontSize: 26),
            ),
          ),
          body: Column(
            children: [
              // 🌟 ENHANCED & BEAUTIFIED "WHAT'S ON YOUR MIND" CARD COMPONENT
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: coffeeBrown.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: coffeeBrown.withOpacity(0.1),
                          backgroundImage: myProfilePic.isNotEmpty ? NetworkImage(myProfilePic) : null,
                          child: myProfilePic.isEmpty
                              ? Icon(Icons.person, color: coffeeBrown, size: 22)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _postController,
                            maxLines: null,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                            decoration: InputDecoration(
                              hintText: "What's on your mind, @$myUsername?",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: Color(0xFFF5EFE2), thickness: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notes, size: 18, color: coffeeBrown.withOpacity(0.4)),
                            const SizedBox(width: 6),
                            Text(
                              "Share a thought...",
                              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: coffeeBrown,
                            foregroundColor: themeBg,
                            elevation: 2,
                            shadowColor: coffeeBrown.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          onPressed: _isPosting ? null : () => _createNewPost(myUsername),
                          child: _isPosting
                              ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text(
                            "Post",
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 14),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // DYNAMIC TIMELINE STREAM
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

                    // 1. Gather all text content that YOU have personally reposted
                    Set<String> myRepostedTexts = allDocs.where((doc) {
                      var postData = doc.data() as Map<String, dynamic>;
                      return postData['authorId'] == widget.userId &&
                          postData['isRepost'] == true;
                    }).map((doc) => (doc.data() as Map<String, dynamic>)['text']?.toString() ?? '').toSet();

                    // 2. Filter root timeline posts while skipping original duplicate entries
                    var timelinePosts = allDocs.where((doc) {
                      var postData = doc.data() as Map<String, dynamic>;
                      String authorId = postData['authorId'] ?? '';
                      String postText = postData['text'] ?? '';
                      bool isRepost = postData['isRepost'] ?? false;
                      bool isRootPost = !postData.containsKey('parentId') || postData['parentId'] == null;

                      // Base check: Must be a top-level post from you or followed friends
                      if (!isRootPost || !allowedUserIds.contains(authorId)) return false;

                      // 🌟 EXCLUSION FILTER: If this is your OWN original post, but you have
                      // already reposted it, drop the original post document from this list
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
                          style: TextStyle(color: Colors.grey[500], height: 1.5),
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
                            _buildPostCard(rootData, rootId, isComment: false),
                            ...children.map((c) => _buildPostCard(c.data() as Map<String, dynamic>, c.id, isComment: true)),
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

  // --- REPLICATED POSTCARD COMPONENT FROM PROFILE & PREVIEW ---
  Widget _buildPostCard(Map<String, dynamic> post, String postId, {required bool isComment}) {
    List likedBy = post['likedBy'] ?? [];
    DateTime dt = (post['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();
    String authorId = post['authorId'] ?? '';

    // 🌟 FIX 4: Only show delete button if YOU are the absolute author who created/reposted this entry document
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
                      return Text(
                        "@$currentName",
                        style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 13),
                      );
                    },
                  ),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(dt),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post['text'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  _actionIcon(
                    likedBy.contains(widget.userId) ? Icons.favorite : Icons.favorite_border,
                    "${likedBy.length}",
                    likedBy.contains(widget.userId) ? Colors.red : coffeeBrown,
                        () => _toggleLike(postId, likedBy),
                  ),
                  const SizedBox(width: 20),
                  _actionIcon(
                    Icons.chat_bubble_outline,
                    "Reply",
                    coffeeBrown,
                        () => _showCommentDialog(postId, post['text'] ?? ""),
                  ),
                  const SizedBox(width: 20),
                  if (!isComment)
                    _actionIcon(
                      Icons.repeat,
                      iHaveReposted ? "Reposted" : "Repost",
                      iHaveReposted ? Colors.green : Colors.blue,
                          () => _toggleRepost(post),
                    ),
                  const Spacer(),
                  // 🌟 FIX 3 & 4: Only draw widget tree icon if true, eliminating white-screen crashes
                  if (isMyPost)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                      onPressed: () => _confirmDelete(postId),
                    ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}