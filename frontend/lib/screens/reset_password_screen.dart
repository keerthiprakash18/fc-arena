import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_code_field.dart';
import 'login_screen.dart';

/// Step two of a password reset: confirm the code and choose a new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.identifier,
    this.devCode,
  });

  final String identifier;

  /// Code echoed back by the server because no mail transport is configured.
  /// Present only in development.
  final String? devCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _hasError = false;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _devCode = widget.devCode;
    if (_devCode != null && _devCode!.isNotEmpty) {
      _codeController.text = _devCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_codeController.text.trim().length != 6) {
      setState(() => _hasError = true);
      showAuthSnack(context, 'Enter the 6-digit code.', error: true);
      return;
    }

    setState(() {
      _submitting = true;
      _hasError = false;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(
      widget.identifier,
      _codeController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;

    setState(() {
      _submitting = false;
      _hasError = !ok;
    });

    if (ok) {
      showAuthSnack(context, 'Password reset. Please sign in.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      showAuthSnack(context, auth.error ?? 'Reset failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _submitting || auth.isLoading;

    return AuthScaffold(
      title: 'NEW PASSWORD',
      subtitle: 'Enter the code sent for ${widget.identifier} and choose a new '
          'password.',
      leading: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.arrow_back_rounded, color: FCColors.white60),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_devCode != null && _devCode!.isNotEmpty) ...[
              AuthInfoBanner(
                icon: Icons.construction_rounded,
                color: FCColors.gold,
                text: 'No mail server is configured yet, so the reset code is '
                    'shown here: $_devCode.',
              ),
              const SizedBox(height: 20),
            ],
            OtpCodeField(
              controller: _codeController,
              enabled: !busy,
              hasError: _hasError,
            ),
            const SizedBox(height: 22),
            AuthField(
              controller: _passwordController,
              label: 'New Password',
              icon: Icons.lock_outline,
              obscure: _obscure,
              textInputAction: TextInputAction.next,
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                  color: FCColors.white40,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Min 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _confirmController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              obscure: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: FCColors.white40,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _passwordController.text) return "Passwords don't match";
                return null;
              },
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: 'SET NEW PASSWORD',
              loading: busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
