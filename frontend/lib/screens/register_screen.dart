import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

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
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final payload = await auth.register(
      username,
      email,
      _passwordController.text,
      gameUid: _gameUidController.text.trim(),
      gameInGameName: _gameNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    if (!mounted) return;

    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Registration failed'),
          backgroundColor: FCColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    // Registration is a two-step handshake: the account only becomes usable
    // once the one-time code is confirmed, so hand off to the OTP screen
    // instead of dropping the user back on login where they would be refused.
    if (payload['otp_required'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            username: username,
            email: email,
            initialDevCode: payload['dev_otp'] as String?,
          ),
        ),
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Account created! Please sign in.'),
        backgroundColor: FCColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FCGradients.hero),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative glows
              Positioned(
                top: -80,
                right: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [FCColors.accent.withValues(alpha: 0.05), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [FCColors.purple.withValues(alpha: 0.04), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        // Logo
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: FCGradients.accent,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: FCColors.accent.withValues(alpha: 0.25),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.sports_soccer, size: 32, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              colors: [FCColors.white, FCColors.accentBright],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join the football tournament platform',
                          style: TextStyle(
                            fontSize: 14,
                            color: FCColors.accent.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Required fields
                        _field(_usernameController, 'Username *', Icons.person_outline, required: true),
                        const SizedBox(height: 14),
                        _field(_emailController, 'Email *', Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress, required: true),
                        const SizedBox(height: 14),
                        _field(_passwordController, 'Password *', Icons.lock_outline, obscure: true, required: true),
                        const SizedBox(height: 14),
                        _field(_confirmPasswordController, 'Confirm Password *', Icons.lock_outline,
                            obscure: true, isConfirm: true, required: true),
                        const SizedBox(height: 24),
                        // Game details section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: FCColors.white05,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FCColors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: FCColors.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.games_outlined,
                                        color: FCColors.accent.withValues(alpha: 0.8), size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'GAME DETAILS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: FCColors.accent.withValues(alpha: 0.8),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _field(_gameUidController, 'Game UID', Icons.badge_outlined),
                              const SizedBox(height: 14),
                              _field(_gameNameController, 'In-Game Name', Icons.sports_esports_outlined),
                              const SizedBox(height: 14),
                              _field(_phoneController, 'Phone Number', Icons.phone_outlined,
                                  keyboardType: TextInputType.phone),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Register button
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) => SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FCColors.accent,
                                foregroundColor: FCColors.pitch,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: FCColors.pitch, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'CREATE ACCOUNT',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account?',
                                style: TextStyle(color: FCColors.white40, fontSize: 14)),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: FCColors.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
    final isPassword = obscure || isConfirm;
    return TextFormField(
      controller: ctrl,
      obscureText: isPassword && (obscure ? _obscure : _obscureConfirm),
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: FCColors.white40),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (obscure ? _obscure : _obscureConfirm)
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: FCColors.white40,
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
