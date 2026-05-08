import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import '../main.dart';
import '../utils/translations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final primaryColor = const Color(0xFF003D1B);

  String _t(String key) => FlousiTranslations.t(context, key);

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_occurred'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _socialSignIn(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.flousi://login-callback/',
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_occurred'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(_t('welcome_back'), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor)),
              Text(_t('login_subtitle'), style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              _buildTextField(_t('email'), Icons.email_rounded, _emailController),
              const SizedBox(height: 20),
              _buildTextField(_t('password'), Icons.lock_rounded, _passwordController, isPassword: true),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: Text(_t('forgot_password'), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_t('login'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.2))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_t('or_continue_with'), style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                  Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.2))),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _buildSocialButton('Google', 'assets/google_logo.png', () => _socialSignIn(OAuthProvider.google))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSocialButton('Apple', 'assets/apple_logo.png', () => _socialSignIn(OAuthProvider.apple))),
                ],
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_t('dont_have_account'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())), child: Text(_t('sign_up'), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: primaryColor, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.all(20)),
      ),
    );
  }

  Widget _buildSocialButton(String label, String asset, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.star_rounded, size: 20, color: Colors.grey), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold))]),
    );
  }
}
