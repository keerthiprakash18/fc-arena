import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import 'reset_password_screen.dart';

/// Step one of a password reset: ask for a code.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final identifier = _identifierController.text.trim();
    final auth = context.read<AuthProvider>();
    final payload = await auth.forgotPassword(identifier);
    if (!mounted) return;

    if (payload == null) {
      showAuthSnack(context, auth.error ?? 'Could not start a reset.', error: true);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          identifier: identifier,
          devCode: payload['dev_otp'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'RESET PASSWORD',
      subtitle: 'Enter your username or email and we will send a 6-digit '
          'code to reset your password.',
      leading: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.arrow_back_rounded, color: FCColors.white60),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      footer: TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(
          'Back to sign in',
          style: TextStyle(color: FCColors.white40, fontSize: 13),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              controller: _identifierController,
              label: 'Username or Email',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: 'SEND RESET CODE',
              icon: Icons.mail_outline_rounded,
              loading: auth.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
