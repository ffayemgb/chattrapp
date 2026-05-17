import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart'; // 🌟 FIXED: Added this explicit import to eliminate the compiler error
import 'profile_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  const MainScreen({super.key, required this.userId});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  final Color themeBg = const Color(0xFFFFFFFF);
  final Color coffeeBrown = const Color(0xFF53161D);

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(userId: widget.userId), // 🌟 Works perfectly now that home_screen.dart is imported
      SearchScreen(currentUserId: widget.userId),
      MessagesScreen(userId: widget.userId),
      NotificationsScreen(userId: widget.userId),
      ProfileScreen(userId: widget.userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: coffeeBrown.withOpacity(0.1), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: themeBg,
          selectedItemColor: coffeeBrown,
          unselectedItemColor: Colors.grey.withOpacity(0.8),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          iconSize: 28,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: "Home",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: "Search",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: "Messages",
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('receiverId', isEqualTo: widget.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  bool hasNotifications = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  return Stack(
                    children: [
                      const Icon(Icons.notifications_none_rounded),
                      if (hasNotifications)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                            constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                          ),
                        ),
                    ],
                  );
                },
              ),
              activeIcon: const Icon(Icons.notifications_rounded),
              label: "Notifications",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}