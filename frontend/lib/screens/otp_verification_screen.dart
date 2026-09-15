import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_code_field.dart';
import 'login_screen.dart';

/// Step two of registration: confirm the one-time code and activate the account.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.username,
    this.email = '',
    this.initialDevCode,
  });

  final String username;
  final String email;

  /// The code the server handed back because it has no mail transport
  /// configured. Present only in development.
  final String? initialDevCode;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _submitting = false;
  bool _hasError = false;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _devCode = widget.initialDevCode;
    if (_devCode != null && _devCode!.isNotEmpty) {
      _codeController.text = _devCode!;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 45]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _hasError = true);
      showAuthSnack(context, 'Enter the 6-digit code.', error: true);
      return;
    }

    setState(() {
      _submitting = true;
      _hasError = false;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(widget.username, code);
    if (!mounted) return;

    setState(() {
      _submitting = false;
      _hasError = !ok;
    });

    if (ok) {
      showAuthSnack(context, 'Account verified. Please sign in.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      showAuthSnack(context, auth.error ?? 'Verification failed', error: true);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final payload = await auth.resendOtp(widget.username);
    if (!mounted) return;

    if (payload == null) {
      showAuthSnack(context, auth.error ?? 'Could not resend the code.', error: true);
      return;
    }

    final code = payload['dev_otp'] as String?;
    setState(() {
      _devCode = code;
      _hasError = false;
      if (code != null && code.isNotEmpty) _codeController.text = code;
    });
    _startCooldown();
    showAuthSnack(context, 'A new code has been sent.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _submitting || auth.isLoading;

    return AuthScaffold(
      title: 'VERIFY ACCOUNT',
      subtitle: widget.email.isEmpty
          ? 'Enter the 6-digit code we sent to activate @${widget.username}.'
          : 'Enter the 6-digit code we sent to ${widget.email}.',
      leading: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.arrow_back_rounded, color: FCColors.white60),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      footer: TextButton(
        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        ),
        child: Text(
          'Back to sign in',
          style: TextStyle(color: FCColors.white40, fontSize: 13),
        ),
      ),
      child: Column(
        children: [
          if (_devCode != null && _devCode!.isNotEmpty) ...[
            AuthInfoBanner(
              icon: Icons.construction_rounded,
              color: FCColors.gold,
              text: 'No mail server is configured yet, so the code is shown here: '
                  '$_devCode. Enter it below to activate the account.',
            ),
            const SizedBox(height: 20),
          ],
          OtpCodeField(
            controller: _codeController,
            enabled: !busy,
            hasError: _hasError,
            onCompleted: (_) => _submit(),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'VERIFY & CONTINUE',
            loading: busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't get the code?",
                style: TextStyle(color: FCColors.white40, fontSize: 13),
              ),
              TextButton(
                onPressed: (_cooldown > 0 || busy) ? null : _resend,
                child: Text(
                  _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
                  style: TextStyle(
                    color: _cooldown > 0 ? FCColors.white40 : FCColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
