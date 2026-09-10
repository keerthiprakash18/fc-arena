import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _gameUidController = TextEditingController();
  final _gameNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _gameUidController.dispose();
    _gameNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      gameUid: _gameUidController.text.trim(),
      gameInGameName: _gameNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Registration failed'),
          backgroundColor: FCColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FCGradients.pitch),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join the tournament',
                      style: TextStyle(fontSize: 13, color: FCColors.accent.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 32),
                    _field(_usernameController, 'Username *', Icons.person_outline, required: true),
                    const SizedBox(height: 14),
                    _field(_emailController, 'Email *', Icons.email_outlined, keyboardType: TextInputType.emailAddress, required: true),
                    const SizedBox(height: 14),
                    _field(_passwordController, 'Password *', Icons.lock_outline, obscure: true, required: true),
                    const SizedBox(height: 14),
                    _field(_confirmPasswordController, 'Confirm Password *', Icons.lock_outline, obscure: true, isConfirm: true, required: true),
                    const SizedBox(height: 20),
                    const Divider(color: FCColors.white10),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.games_outlined, color: FCColors.accent.withValues(alpha: 0.7), size: 18),
                        const SizedBox(width: 8),
                        Text('GAME DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: FCColors.accent.withValues(alpha: 0.7), letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _field(_gameUidController, 'Game UID', Icons.badge_outlined),
                    const SizedBox(height: 14),
                    _field(_gameNameController, 'In-Game Name', Icons.sports_esports_outlined),
                    const SizedBox(height: 14),
                    _field(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 28),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) => SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FCColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('CREATE ACCOUNT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: TextStyle(color: FCColors.white30, fontSize: 13)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Sign In', style: TextStyle(color: FCColors.accent, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    bool isConfirm = false,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: (obscure && _obscure) || (isConfirm && _obscureConfirm),
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: (obscure || isConfirm)
            ? IconButton(
                icon: Icon(
                  (obscure ? _obscure : _obscureConfirm) ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() {
                  if (obscure) _obscure = !_obscure;
                  if (isConfirm) _obscureConfirm = !_obscureConfirm;
                }),
              )
            : null,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) {
          if (required) return 'Required';
          return null;
        }
        if (ctrl == _passwordController && v.length < 8) return 'Min 8 characters';
        if (ctrl == _emailController && !v.contains('@')) return 'Invalid email';
        if (isConfirm && v != _passwordController.text) return 'Passwords don\'t match';
        return null;
      },
    );
  }
}
