import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.prefixIcon,
    this.autofillHints,
    this.inputFormatters,
    this.readOnly = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final IconData? prefixIcon;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: const Color(0xFF3396A8).withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        autofillHints: widget.autofillHints,
        inputFormatters: widget.inputFormatters,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: widget.prefixIcon == null
              ? null
              : AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _focused ? 1.1 : 1,
                  child: Icon(
                    widget.prefixIcon,
                    color: _focused ? const Color(0xFF177385) : null,
                  ),
                ),
        ),
      ),
    );
  }
}
