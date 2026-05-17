import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart'; // 🌟 MUST BE HERE to fix the red line on MainScreen

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _currentPage = 0;
  bool isLogin = true;
  bool isLoading = false;
  bool _obscurePassword = true; // 🌟 TRACKS PASSWORD VISIBILITY STATE

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || (!isLogin && _usernameController.text.isEmpty)) {
      _showMsg("Please fill in all fields", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        var result = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _emailController.text.trim())
            .where('password', isEqualTo: _passwordController.text.trim())
            .get();

        if (result.docs.isNotEmpty) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen(userId: result.docs.first.id)),
          );
        } else {
          _showMsg("Invalid email or password", isError: true);
        }
      } else {
        // REGISTER
        DocumentReference docRef = await FirebaseFirestore.instance.collection('users').add({
          'username': _usernameController.text.trim().toLowerCase(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'bio': 'New to Chattr!',
          'profilePic': '',
          'followers': 0,
          'following': 0,
          'postsCount': 0,
          'following_list': [], // Setup empty array structure
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(userId: docRef.id)),
        );
      }
    } catch (e) {
      _showMsg("Error: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? const Color(0xFF53161D) : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFFFFF), Colors.white.withOpacity(0.5)],
          ),
        ),
        child: Stack(
          children: [
            _currentPage == 0 ? _buildIntro() : _buildAuthForm(),
            if (isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF53161D))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('images/chattr.png', height: 180),
          const SizedBox(height: 20),
          const Text(
            "CHATTR",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF53161D),
              letterSpacing: 4,
            ),
          ),
          const Text(
            "where conversations click",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: () => setState(() => _currentPage = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF53161D),
              foregroundColor: const Color(0xFFFFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 8,
              shadowColor: const Color(0xFF53161D).withOpacity(0.5),
            ),
            child: const Text('GET STARTED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('images/chattr.png', height: 100),
            const SizedBox(height: 40),
            Text(
              isLogin ? "Welcome Back" : "Join the Community",
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF53161D)
              ),
            ),
            const SizedBox(height: 25),
            if (!isLogin) _inputField("Username", _usernameController, Icons.alternate_email),
            _inputField("Email", _emailController, Icons.email_outlined),
            _inputField("Password", _passwordController, Icons.lock_outline, isPass: true),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53161D),
                foregroundColor: const Color(0xFFFFFFFF),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
              ),
              child: Text(isLogin ? "LOGIN" : "CREATE ACCOUNT", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    TextSpan(text: isLogin ? "Don't have an account? " : "Already have an account? "),
                    TextSpan(
                      text: isLogin ? "Sign Up" : "Log In",
                      style: const TextStyle(color: Color(0xFF53161D), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController controller, IconData icon, {bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: TextField(
          controller: controller,
          // 🌟 DYNAMIC VISIBILITY SWITCHING FOR PASSWORD TYPE FIELDS
          obscureText: isPass ? _obscurePassword : false,
          style: const TextStyle(color: Color(0xFF53161D)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF53161D)),
            // 🌟 INJECT TOGGLE ICON PATTERN
            suffixIcon: isPass
                ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF53161D).withOpacity(0.6),
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            )
                : null,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none
            ),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.05))
            ),
          ),
        ),
      ),
    );
  }
}