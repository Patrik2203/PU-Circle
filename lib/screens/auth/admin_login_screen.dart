import 'package:flutter/material.dart';
import '../../firebase/auth_service.dart';
import '../../utils/colors.dart';
import '../../utils/helpers.dart';
import '../admin/admin_dashboard.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passkeyController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Admin passkey check
  final String _adminPasskey = '79770051419136567648';

  void _adminLogin() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _passkeyController.text.isEmpty) {
      AppHelpers.showSnackBar(context, 'Please fill all fields');
      return;
    }

    // Verify admin passkey
    if (_passkeyController.text != _adminPasskey) {
      AppHelpers.showSnackBar(context, 'Invalid admin passkey');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user has admin role
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Authentication failed');
      }

      final userData = await _authService.getUserData(currentUser.uid);
      if (userData == null || userData.isAdmin) {
        // Log out if not admin
        await _authService.logout();
        throw Exception('You do not have admin privileges');
      }

      if (!mounted) return;

      // Navigate to admin dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } catch (e) {
      AppHelpers.showSnackBar(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passkeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
        backgroundColor: AppColors.adminSecondary,
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: Container(), flex: 1),

              // App Logo
              const Text(
                'PU Circle',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminSecondary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Email Input
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Admin Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),

              // Password Input
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // Admin Passkey Input
              TextFormField(
                controller: _passkeyController,
                decoration: const InputDecoration(
                  hintText: 'Admin Passkey',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // Login Button
              InkWell(
                onTap: _isLoading ? null : _adminLogin,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    color: AppColors.adminSecondary,
                  ),
                  child: _isLoading
                      ? LoadingAnimationWidget.staggeredDotsWave(
                    color: Colors.white,
                    size: 24,
                  )
                      : const Text(
                    'Admin Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              Flexible(flex: 2, child: Container()),
            ],
          ),
        ),
      ),
    );
  }
}