import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Search input for the library pane. Owns its own [TextEditingController]
/// so parent rebuilds (e.g. from the 1Hz player ticker elsewhere on screen)
/// never reset the cursor position or composing state.
class LibrarySearchField extends StatefulWidget {
  const LibrarySearchField({required this.onChanged, super.key});

  final ValueChanged<String> onChanged;

  @override
  State<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<LibrarySearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OnScreenTextField(
      controller: _controller,
      onChanged: widget.onChanged,
      semanticLabel: l10n.text(AppTextKey.mediaSearchSemantic),
      hintText: l10n.text(AppTextKey.mediaSearchHint),
      prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
      suffixIcon: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, child) {
          if (value.text.isEmpty) {
            return const SizedBox.shrink();
          }
          return Semantics(
            button: true,
            label: l10n.text(AppTextKey.mediaSearchClearSemantic),
            child: IconButton(
              icon: const Icon(Icons.close,
                  color: AppColors.onSurfaceVariant, size: 18),
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            ),
          );
        },
      ),
    );
  }
}
