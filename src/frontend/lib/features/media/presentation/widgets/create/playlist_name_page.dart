import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_back_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_wide_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// A page with one name field and one action button under it: creating a
/// playlist ([PlaylistCreatePage]) and renaming one ([PlaylistRenamePage])
/// look the same.
///
/// The button does what **Fertig** on the on-screen keyboard does, so a
/// keyboard closed with a tap beside it still leaves a way forward. It stays
/// greyed out while the name is empty or [isBusy].
class PlaylistNamePage extends StatefulWidget {
  const PlaylistNamePage({
    required this.titleKey,
    required this.submitKey,
    required this.submitIcon,
    required this.backSemanticLabelKey,
    required this.onBack,
    required this.onSubmit,
    this.initialName = '',
    this.errorKey,
    this.isBusy = false,
    super.key,
  });

  final AppTextKey titleKey;
  final AppTextKey submitKey;
  final IconData submitIcon;
  final AppTextKey backSemanticLabelKey;
  final VoidCallback onBack;

  /// Called with the name as typed, from the button and from **Fertig**.
  final ValueChanged<String> onSubmit;

  final String initialName;
  final AppTextKey? errorKey;
  final bool isBusy;

  @override
  State<PlaylistNamePage> createState() => _PlaylistNamePageState();
}

class _PlaylistNamePageState extends State<PlaylistNamePage> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );

  @override
  void initState() {
    super.initState();
    _nameController.selection = TextSelection.collapsed(
      offset: widget.initialName.length,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isBusy) {
      return;
    }
    widget.onSubmit(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorKey = widget.errorKey;

    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MediaBackButton(
                  onBack: widget.onBack,
                  semanticLabelKey: widget.backSemanticLabelKey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.text(widget.titleKey).toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            OnScreenTextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 40,
              onSubmitted: (_) => _submit(),
              semanticLabel: l10n.text(AppTextKey.mediaPlaylistNameHint),
              hintText: l10n.text(AppTextKey.mediaPlaylistNameHint),
            ),
            if (errorKey != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.text(errorKey),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, child) => SizedBox(
                width: double.infinity,
                child: MediaWideButton(
                  icon: widget.submitIcon,
                  label: l10n.text(widget.submitKey),
                  isEnabled: !widget.isBusy && value.text.trim().isNotEmpty,
                  onTap: _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
