import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Labelled form field. A thin wrapper around [TextFormField], so existing
/// controllers and validators work unchanged. The label sits above the field;
/// the field itself uses the theme's input decoration. Password fields get a
/// show/hide button. An empty label hides the label row (the hint then
/// describes the field).
class AppTextField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final Widget? suffix;

  /// When false the field is greyed out and the password toggle is disabled.
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.onSaved,
    this.suffix,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final Widget? suffixIcon = widget.obscure
        ? IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: _hidden ? 'Show password' : 'Hide password',
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: widget.enabled
                ? () => setState(() => _hidden = !_hidden)
                : null,
          )
        : widget.suffix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s1),
        ],
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: widget.obscure && _hidden,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          onSaved: widget.onSaved,
          style: AppText.body.copyWith(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
