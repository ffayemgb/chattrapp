import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  Uint8List? _tempProfileBytes;

  final Color themeBg = const Color(0xFFFEFAEF);
  final Color coffeeBrown = const Color(0xFF53161D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- NOTES LOGIC ---
  String _getNoteTime(Timestamp? timestamp) {
    if (timestamp == null) return "0s";
    final now = DateTime.now();
    final diff = now.difference(timestamp.toDate());

    if (diff.inSeconds < 60) return "${diff.inSeconds}s";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "exp"; // This shouldn't show if the 24h check passes
  }

  void _showNoteOptions(Map<String, dynamic>? noteData, bool hasValidNote) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasValidNote) ...[
              Text(
                noteData!['text'],
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                "${_getNoteTime(noteData['createdAt'])} ago",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ] else
              const Text(
                "Share a thought...",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: coffeeBrown,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showAddNoteInput();
              },
              child: const Text("Leave a new note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (hasValidNote)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('notes').doc(widget.userId).delete();
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("Delete note", style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showAddNoteInput() {
    TextEditingController noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("New Note", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteCtrl,
          maxLength: 60,
          autofocus: true,
          decoration: const InputDecoration(hintText: "What's on your mind?"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: coffeeBrown))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (noteCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('notes').doc(widget.userId).set({
                'text': noteCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'userId': widget.userId,
              });
              // Fetch friends and notify them
              // Fetch your friend list to notify them
              var myDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
              List friends = (myDoc.data() as Map<String, dynamic>)['following_list'] ?? [];

              for (String friendId in friends) {
                FirebaseFirestore.instance.collection('notifications').add({
                  'type': 'note',
                  'message': 'shared a new note',
                  'senderId': widget.userId,
                  'receiverId': friendId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Share", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNewPostDialog(Map<String, dynamic> userData, {String? parentPostId}) {
    TextEditingController postCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(parentPostId == null ? "What's new?" : "Add a comment",
            style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: TextField(
            controller: postCtrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: parentPostId == null ? "Type your thoughts..." : "Reply to this...",
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: coffeeBrown))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (postCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('posts').add({
                'text': postCtrl.text.trim(),
                'authorId': widget.userId,
                'username': userData['username'] ?? 'user',
                'isRepost': false,
                'createdAt': FieldValue.serverTimestamp(),
                'likedBy': [],
                'imageUrl': '',
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

  // --- UI BUILDERS ---
  Widget _showImage(String url, {double? width, double? height}) {
    return Image.network(
      url, width: width, height: height, fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Scaffold(backgroundColor: themeBg, body: const Center(child: CircularProgressIndicator()));
        var userData = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: themeBg,
          floatingActionButton: FloatingActionButton(
            backgroundColor: coffeeBrown,
            onPressed: () => _showNewPostDialog(userData),
            child: const Icon(Icons.add_comment_rounded, color: Colors.white),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: themeBg,
                  elevation: 0,
                  pinned: true,
                  floating: true,
                  title: Text("My Profile", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.w900, fontSize: 26)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: themeBg,
                            title: const Text("Logout"),
                            content: const Text("Are you sure you want to log out?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const WelcomeScreen())
                                ),
                                child: const Text("Logout", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: coffeeBrown),
                      onPressed: () => _showAccountSettingsDialog(),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35),
                    child: Column(
                      children: [
                        _buildHeader(userData),
                        const SizedBox(height: 30),
                        _buildStats(),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => _showEditProfileDialog(userData),
                          child: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: coffeeBrown,
                      indicatorColor: coffeeBrown,
                      tabs: const [Tab(text: "Posts"), Tab(text: "Likes"), Tab(text: "Reposts")],
                    ),
                    themeBg,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildFeed(userData,
                    query: FirebaseFirestore.instance
                        .collection('posts')
                        .where('authorId', isEqualTo: widget.userId)
                        .where('isRepost', isEqualTo: false)
                        .where('parentId', isNull: true) // Filters out replies from main feed
                ),
                _buildFeed(userData,
                    query: FirebaseFirestore.instance
                        .collection('posts')
                        .where('likedBy', arrayContains: widget.userId)
                        .where('parentId', isNull: true) // Prevents liked comments from appearing as standalone posts
                ),
                _buildFeed(userData,
                    query: FirebaseFirestore.instance
                        .collection('posts')
                        .where('authorId', isEqualTo: widget.userId)
                        .where('isRepost', isEqualTo: true)
                  // .where('parentId', isNull: true)  Prevents reposted comments from appearing as standalone posts
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> userData) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('notes').doc(widget.userId).snapshots(),
      builder: (context, noteSnap) {
        var noteData = noteSnap.data?.data() as Map<String, dynamic>?;
        bool hasValidNote = false;

        if (noteData != null && noteData['createdAt'] != null) {
          DateTime createdAt = (noteData['createdAt'] as Timestamp).toDate();
          // ONLY true if less than 24 hours have passed
          if (DateTime.now().difference(createdAt).inHours < 24) {
            hasValidNote = true;
          }
        }

        return Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _showNoteOptions(noteData, hasValidNote),
                  child: CircleAvatar(
                    radius: 40, backgroundColor: coffeeBrown,
                    child: ClipOval(
                      child: _tempProfileBytes != null
                          ? Image.memory(_tempProfileBytes!, width: 80, height: 80, fit: BoxFit.cover)
                          : (userData['profilePic'] != null && userData['profilePic'] != '')
                          ? _showImage(userData['profilePic'], width: 80, height: 80)
                          : const Icon(Icons.person, color: Colors.white, size: 40),
                    ),
                  ),
                ),
                if (hasValidNote)
                  Positioned(
                    top: -35,
                    left: -10,
                    child: GestureDetector(
                      onTap: () => _showNoteOptions(noteData, hasValidNote),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 130),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          noteData!['text'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                if (!hasValidNote)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.add_circle, color: coffeeBrown, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@${userData['username']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(children: [
                  Icon(Icons.location_on, size: 14, color: coffeeBrown),
                  Text(" ${userData['location'] ?? 'Earth'}", style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(width: 10),
                  Icon(Icons.person_pin, size: 14, color: coffeeBrown),
                  Text(" ${userData['gender'] ?? 'Secret'}", style: TextStyle(color: Colors.grey[700])),
                ]),
                const SizedBox(height: 5),
                Text(userData['bio'] ?? 'No bio yet...', style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ))
          ],
        );
      },
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('authorId', isEqualTo: widget.userId)
              .where('isRepost', isEqualTo: false)
              .where('parentId', isNull: true) // Only counts original posts, not comments on others
              .snapshots(),
          builder: (context, snapshot) {
            String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : '0';
            return _statBox(count, "Posts");
          },
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('authorId', isEqualTo: widget.userId)
              .where('isRepost', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : '0';
            return _statBox(count, "Reposts");
          },
        ),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              List friends = data['following_list'] ?? [];
              count = friends.length;
            }
            return _statBox(count.toString(), "Friends");
          },
        ),
      ],
    );
  }

  Widget _statBox(String count, String label) => Column(
    children: [
      Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: coffeeBrown)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );

  Widget _buildFeed(Map<String, dynamic> userData, {required Query query}) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        List<QueryDocumentSnapshot> allDocs = snapshot.data!.docs;
        if (allDocs.isEmpty) return const Center(child: Text("Nothing to see here yet."));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').snapshots(),
          builder: (context, globalSnap) {
            if (!globalSnap.hasData) return const SizedBox();
            List<QueryDocumentSnapshot> globalDocs = globalSnap.data!.docs;

            // 1. Sort the main timeline posts by date
            allDocs.sort((a, b) {
              Timestamp timeA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp? ?? Timestamp.now();
              Timestamp timeB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp? ?? Timestamp.now();
              return timeB.compareTo(timeA);
            });

            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: allDocs.length,
              itemBuilder: (context, index) {
                var rootDoc = allDocs[index];
                var rootData = rootDoc.data() as Map<String, dynamic>;
                String rootId = rootDoc.id;

                // 2. Find replies to this post locally (if they exist)
                var children = globalDocs.where((d) => (d.data() as Map)['parentId'] == rootId).toList();
                children.sort((a, b) => ((a.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now())
                    .compareTo((b.data() as Map)['createdAt'] as Timestamp? ?? Timestamp.now()));

                return Column(
                  children: [
                    _postCard(rootData, rootId, userData, isComment: false),
                    ...children.map((c) => _postCard(c.data() as Map<String, dynamic>, c.id, userData, isComment: true)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _postCard(Map<String, dynamic> post, String postId, Map<String, dynamic> userData, {required bool isComment}) {
    List likedBy = post['likedBy'] ?? [];
    DateTime dt = (post['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();
    String authorId = post['authorId'] ?? ''; // We use this ID to fetch the current username

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
              // --- UPDATED REPOST USERNAME DISPLAY LOGIC ---
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc((post['isRepost'] == true && post['originalAuthorId'] != null && post['originalAuthorId'].toString().isNotEmpty)
                    ? post['originalAuthorId']
                    : authorId)
                    .get(),
                builder: (context, userSnap) {
                  String liveUsername = post['username'] ?? 'user';
                  if (userSnap.hasData && userSnap.data!.exists) {
                    liveUsername = (userSnap.data!.data() as Map<String, dynamic>)['username'] ?? liveUsername;
                  }
                  return Text(
                    "@$liveUsername",
                    style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold, fontSize: 13),
                  );
                },
              ),
              Text(DateFormat('MMM d, yyyy • h:mm a').format(dt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post['text'] ?? ''),
          const Divider(height: 20),
          Row(
            children: [
              _actionIcon(
                  likedBy.contains(widget.userId) ? Icons.favorite : Icons.favorite_border,
                  "${likedBy.length}",
                  likedBy.contains(widget.userId) ? Colors.red : coffeeBrown,
                      () => _toggleLike(postId, likedBy)
              ),
              const SizedBox(width: 20),
              _actionIcon(Icons.chat_bubble_outline, "Reply", coffeeBrown,
                      () => _showNewPostDialog(userData, parentPostId: postId)),
              const SizedBox(width: 20),

              if (!isComment)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts')
                      .where('authorId', isEqualTo: widget.userId)
                      .where('text', isEqualTo: post['text'])
                      .where('isRepost', isEqualTo: true)
                      .snapshots(),
                  builder: (context, repostSnap) {
                    bool iHaveReposted = repostSnap.hasData && repostSnap.data!.docs.isNotEmpty;
                    return _actionIcon(
                        Icons.repeat,
                        iHaveReposted ? "Reposted" : "Repost",
                        iHaveReposted ? Colors.green : Colors.blue,
                            () => _toggleRepost(post)
                    );
                  },
                ),

              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  onPressed: () => _confirmDelete(postId)
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color))
        ])
    );
  }

  // --- ACTIONS LOGIC ---
  void _toggleLike(String postId, List likedBy) async {
    if (likedBy.contains(widget.userId)) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likedBy': FieldValue.arrayRemove([widget.userId])});
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likedBy': FieldValue.arrayUnion([widget.userId])});
    }
  }

  void _toggleRepost(Map<String, dynamic> post) async {
    var existing = await FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', isEqualTo: widget.userId)
        .where('text', isEqualTo: post['text'])
        .where('isRepost', isEqualTo: true)
        .get();

    if (existing.docs.isNotEmpty) {
      for (var doc in existing.docs) {
        await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
      }
    } else {
      // 🌟 UPDATED HERE: Match the same Firestore layout data packet mapping
      await FirebaseFirestore.instance.collection('posts').add({
        'text': post['text'],
        'authorId': widget.userId,
        'originalAuthorId': post['originalAuthorId'] ?? post['authorId'] ?? '', // 👈 STORES ORIGINAL WRITER ID
        'username': post['username'],
        'isRepost': true,
        'createdAt': FieldValue.serverTimestamp(),
        'likedBy': [],
      });
    }
  }

  void _confirmDelete(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        title: const Text("Delete Post?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
            Navigator.pop(context);
          }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // --- PROFILE EDITING LOGIC ---
  Future<void> _pickAndUploadImage({bool isProfilePic = false}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    setState(() {
      _isUploading = true;
      if (isProfilePic) _tempProfileBytes = file.bytes;
    });

    try {
      String fileName = isProfilePic ? 'profiles/${widget.userId}.jpg' : 'post_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(file.bytes!, SettableMetadata(contentType: 'image/jpeg'));
      String downloadUrl = await ref.getDownloadURL();

      if (isProfilePic) {
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'profilePic': downloadUrl});
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showEditProfileDialog(Map<String, dynamic> userData) {
    TextEditingController bioCtrl = TextEditingController(text: userData['bio'] ?? '');
    TextEditingController userCtrl = TextEditingController(text: userData['username'] ?? '');
    TextEditingController locCtrl = TextEditingController(text: userData['location'] ?? '');
    String selectedGender = userData['gender'] ?? 'Prefer not to say';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: themeBg,
          insetPadding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit Profile", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _pickAndUploadImage(isProfilePic: true);
                      setDialogState(() {});
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: coffeeBrown,
                      child: ClipOval(
                        child: _tempProfileBytes != null
                            ? Image.memory(_tempProfileBytes!, width: 100, height: 100, fit: BoxFit.cover)
                            : (userData['profilePic'] != null && userData['profilePic'] != '')
                            ? _showImage(userData['profilePic'], width: 100, height: 100)
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _editField(userCtrl, "Username", Icons.person_outline),
                  _editField(bioCtrl, "Bio", Icons.info_outline, isLong: true),
                  _editField(locCtrl, "Location", Icons.location_on_outlined),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: InputDecoration(
                      labelText: "Gender",
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Male', 'Female', 'Others', 'Prefer not to say']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setDialogState(() => selectedGender = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: coffeeBrown))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                  'username': userCtrl.text.trim(),
                  'bio': bioCtrl.text.trim(),
                  'location': locCtrl.text.trim(),
                  'gender': selectedGender,
                });
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSettingsDialog() {
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController currentPassCtrl = TextEditingController();
    TextEditingController newPassCtrl = TextEditingController();
    TextEditingController confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Account Settings", style: TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editField(emailCtrl, "New Email", Icons.email_outlined),
              const Divider(),
              _editField(currentPassCtrl, "Current Password", Icons.lock_outline),
              _editField(newPassCtrl, "New Password", Icons.lock_reset),
              _editField(confirmPassCtrl, "Confirm New Password", Icons.check_circle_outline),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: coffeeBrown))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
            onPressed: () {
              // Basic Validation
              if (newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
                return;
              }

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: themeBg,
                  title: const Text("Save Changes?"),
                  content: const Text("Are you sure you want to update your account credentials?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
                    TextButton(
                      onPressed: () async {
                        Map<String, dynamic> updates = {};
                        if (emailCtrl.text.isNotEmpty) updates['email'] = emailCtrl.text.trim();
                        if (newPassCtrl.text.isNotEmpty) updates['password'] = newPassCtrl.text.trim();

                        if (updates.isNotEmpty) {
                          await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(updates);
                        }

                        Navigator.pop(context); // Close confirm
                        Navigator.pop(context); // Close settings
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Updated!")));
                      },
                      child: const Text("Yes", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon, {bool isLong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        maxLines: isLong ? 3 : 1,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: coffeeBrown),
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);
  final TabBar _tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}