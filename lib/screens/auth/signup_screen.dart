import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/storage_service.dart';
import '../../utils/colors.dart';
import '../../utils/helpers.dart';
import 'login_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  File? _image;
  String _selectedGender = 'male';
  bool _isSingle = false;

  Future<void> _selectImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  void _signup() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      AppHelpers.showSnackBar(context, 'Please fill all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? profileImageUrl;

      // Upload profile image if selected
      if (_image != null) {
        profileImageUrl = await _storageService.uploadProfileImage(
          _image!,
          'profile_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      print("About to create user with: Email: ${_emailController.text.trim()}, Username: ${_usernameController.text.trim()}, Gender: $_selectedGender");

      // Create user with email and password
      UserCredential userCredential = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        gender: _selectedGender,
        isSingle: _isSingle,
        profileImageUrl: profileImageUrl,
      );

      // Check if user was created in Firestore
      bool userExists = await _authService.userExistsInFirestore(userCredential.user!.uid);
      if (!userExists) {
        throw Exception("Failed to create user profile. Please try again.");
      }

      if (!mounted) return;

      AppHelpers.showSnackBar(
        context,
        'Account created successfully!',
      );

      // Navigate back to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    } catch (e) {
      print("Signup error: $e");
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
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Image Selector
              Stack(
                children: [
                  _image != null
                      ? CircleAvatar(
                    radius: 64,
                    backgroundImage: FileImage(_image!),
                  )
                      : const CircleAvatar(
                    radius: 64,
                    backgroundColor: AppColors.textLight,
                    child: Icon(
                      Icons.person,
                      size: 64,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: _selectImage,
                      icon: const Icon(
                        Icons.add_a_photo,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Username Input
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Email Input
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryLight),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password Input
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // Bio Input
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  hintText: 'Bio (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Gender Selection
              Row(
                children: [
                  const Text('Gender: ', style: TextStyle(fontSize: 16)),
                  Radio(
                    value: 'male',
                    groupValue: _selectedGender,
                    activeColor: AppColors.accent,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value.toString();
                      });
                    },
                  ),
                  const Text('Male'),
                  const SizedBox(width: 16),
                  Radio(
                    value: 'female',
                    groupValue: _selectedGender,
                    activeColor: AppColors.accent,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value.toString();
                      });
                    },
                  ),
                  const Text('Female'),
                ],
              ),
              const SizedBox(height: 16),

              // Single Status Selection
              Row(
                children: [
                  const Text('Single: ', style: TextStyle(fontSize: 16)),
                  Switch(
                    value: _isSingle,
                    activeColor: AppColors.accentDark,
                    onChanged: (value) {
                      setState(() {
                        _isSingle = value;
                      });
                    },
                  ),
                  const Text('(Not shown publicly)'),
                ],
              ),
              const SizedBox(height: 24),

              // Signup Button
              InkWell(
                onTap: _isLoading ? null : _signup,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    gradient: AppColors.primaryGradient,  // Apply gradient,
                  ),
                  child: _isLoading
                      ? LoadingAnimationWidget.staggeredDotsWave(
                    color: AppColors.textOnPrimary,
                    size: 24,
                  )
                      : const Text(
                    'Sign up',
                    style: TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Login Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Log in",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}