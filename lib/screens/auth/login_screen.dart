import 'package:flutter/material.dart';
import '../../firebase/auth_service.dart';
import '../../utils/colors.dart';
import '../../utils/helpers.dart';
import 'signup_screen.dart';
import 'admin_login_screen.dart';
import '../home/home_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      AppHelpers.showSnackBar(context, 'Please fill all fields');
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

      if (!mounted) return;

      // Navigate to home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showSnackBar(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignupScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: Container(), flex: 2),

              // App Logo
              const Text(
                'PU Circle',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary, // Fixed color reference
                ),
              ),
              const SizedBox(height: 64),

              // Email Input
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
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

              // Login Button
              InkWell(
                onTap: _isLoading ? null : _login,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    color: AppColors.primary, // Fixed color reference
                  ),
                  child: _isLoading
                      ? LoadingAnimationWidget.staggeredDotsWave(
                    color: Colors.white,
                    size: 24,
                  )
                      : const Text(
                    'Log in',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Signup Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: _isLoading ? null : _navigateToSignup,
                    child: const Text(
                      "Sign up",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Admin Login Navigation
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdminLoginScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Admin Login",
                  style: TextStyle(
                    color: AppColors.accent, // Fixed color reference
                  ),
                ),
              ),

              Flexible(child: Container(), flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}