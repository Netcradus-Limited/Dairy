import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Touch-Friendly 6-Digit OTP PIN Input Widget with System SMS / OTP Autofill Support
class OtpInputField extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const OtpInputField({
    super.key,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Pre-populate with space to detect backspace on empty fields across all platforms (mobile IME)
    _controllers = List.generate(6, (_) => TextEditingController(text: ' '));
    for (var node in _focusNodes) {
      node.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.removeListener(_onFocusChange);
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isEmpty) {
      // Put the space back so we can detect future deletions
      _controllers[index].text = ' ';

      if (index > 0) {
        // Clear the previous controller's digit and set it back to space
        _controllers[index - 1].text = ' ';
        _focusNodes[index - 1].requestFocus();
      }
    } else {
      final cleanDigits = value.replaceAll(RegExp(r'\D'), '');

      // 1. Full OTP Autofill or Pasted 6-digit code
      if (cleanDigits.length >= 6) {
        final code = cleanDigits.substring(0, 6);
        for (int i = 0; i < 6; i++) {
          _controllers[i].value = TextEditingValue(
            text: code[i],
            selection: const TextSelection.collapsed(offset: 1),
          );
        }
        for (var node in _focusNodes) {
          node.unfocus();
        }
        widget.onChanged?.call(code);
        widget.onCompleted(code);
        return;
      }

      // 2. Partial multi-digit paste (2 to 5 digits)
      if (cleanDigits.length > 1) {
        int targetIndex = index;
        for (int i = 0; i < cleanDigits.length && (targetIndex + i) < 6; i++) {
          _controllers[targetIndex + i].value = TextEditingValue(
            text: cleanDigits[i],
            selection: const TextSelection.collapsed(offset: 1),
          );
        }
        final nextFocusIndex = targetIndex + cleanDigits.length;
        if (nextFocusIndex < 6) {
          _focusNodes[nextFocusIndex].requestFocus();
        } else {
          _focusNodes[5].unfocus();
        }

        final code =
            _controllers.map((c) => c.text.replaceAll(' ', '')).join();
        widget.onChanged?.call(code);
        if (code.length == 6) {
          widget.onCompleted(code);
        }
        return;
      }

      // 3. Single digit manual typing
      if (cleanDigits.isNotEmpty) {
        final digit = cleanDigits.substring(cleanDigits.length - 1);
        _controllers[index].value = TextEditingValue(
          text: digit,
          selection: TextSelection.collapsed(offset: digit.length),
        );

        if (index < 5) {
          _focusNodes[index + 1].requestFocus();
        } else {
          _focusNodes[index].unfocus();
        }
      }
    }

    final code = _controllers.map((c) {
      return c.text.replaceAll(' ', '');
    }).join();

    widget.onChanged?.call(code);
    if (code.length == 6) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          final isFocused = _focusNodes[index].hasFocus;
          final hasValue =
              _controllers[index].text.replaceAll(' ', '').isNotEmpty;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 48),
                  child: SizedBox(
                    height: 58,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFF28541C) // Focused deep green
                              : hasValue
                                  ? const Color(0xFF3B7228) // Filled green
                                  : const Color(
                                      0xFF7FA873), // Clearly visible inactive green
                          width: isFocused ? 2.2 : (hasValue ? 1.8 : 1.5),
                        ),
                        boxShadow: [
                          if (isFocused)
                            BoxShadow(
                              color: const Color(0xFF28541C)
                                  .withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(skipTraversal: true),
                        onKeyEvent: (KeyEvent event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowLeft &&
                                index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight &&
                                index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                          }
                        },
                        child: Center(
                          child: TextFormField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            autofillHints: const [AutofillHints.oneTimeCode],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            cursorColor: const Color(0xFF28541C),
                            textInputAction: index < 5
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              final code = _controllers
                                  .map((c) => c.text.replaceAll(' ', ''))
                                  .join();
                              if (code.length == 6) {
                                widget.onCompleted(code);
                              }
                            },
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B4315),
                            ),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(6),
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\s]')),
                            ],
                            onChanged: (value) => _onDigitChanged(index, value),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
