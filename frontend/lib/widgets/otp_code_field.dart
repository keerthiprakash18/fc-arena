import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A six-box one-time-code field.
///
/// Built from six single-character [TextField]s so it works on every platform
/// without a third-party dependency (the project deliberately ships zero extra
/// packages). Typing advances, backspace retreats, and pasting a full code from
/// the clipboard fills every box at once.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.autofocus = true,
    this.enabled = true,
    this.onCompleted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final bool hasError;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _boxes;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _boxes = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    // Keep the external controller in sync with whatever is typed.
    widget.controller.addListener(_syncFromExternal);
    _seedFromController();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternal);
    for (final b in _boxes) {
      b.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _seedFromController() {
    final value = widget.controller.text;
    for (var i = 0; i < widget.length; i++) {
      _boxes[i].text = i < value.length ? value[i] : '';
    }
  }

  void _syncFromExternal() {
    final external = widget.controller.text;
    final current = _value;
    if (external == current) return;
    _seedFromController();
    if (mounted) setState(() {});
  }

  String get _value => _boxes.map((b) => b.text).join();

  void _publish() {
    widget.controller.text = _value;
    if (_value.length == widget.length) {
      widget.onCompleted?.call(_value);
    }
  }

  void _onChanged(int index, String raw) {
    // A paste lands in one box — spread it across the rest.
    if (raw.length > 1) {
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _boxes[i].text = i < digits.length ? digits[i] : '';
      }
      final next = digits.length.clamp(0, widget.length - 1);
      _nodes[next].requestFocus();
      setState(_publish);
      return;
    }

    if (raw.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    setState(_publish);
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _boxes[index].text.isEmpty &&
        index > 0) {
      _nodes[index - 1].requestFocus();
      _boxes[index - 1].clear();
      setState(_publish);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final available = constraints.maxWidth - spacing * (widget.length - 1);
        final boxWidth = (available / widget.length).clamp(38.0, 56.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = _boxes[i].text.isNotEmpty;
            final borderColor = widget.hasError
                ? FCColors.red
                : filled
                    ? FCColors.accent
                    : FCColors.white20;
            return Padding(
              padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : spacing),
              child: SizedBox(
                width: boxWidth,
                child: Focus(
                  onKeyEvent: (node, event) => _onKey(i, event),
                  child: TextField(
                    controller: _boxes[i],
                    focusNode: _nodes[i],
                    enabled: widget.enabled,
                    autofocus: widget.autofocus && i == 0,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: widget.length, // allows a paste to land whole
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      filled: true,
                      fillColor: FCColors.white05,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor, width: 1.4),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: widget.hasError ? FCColors.red : FCColors.accent,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (v) => _onChanged(i, v),
                    onTap: () => _boxes[i].selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _boxes[i].text.length,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
