import 'dart:async';

import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

import 'keyboard_layout.dart';
import 'on_screen_keyboard_controller.dart';
import 'on_screen_keyboard_scope.dart';

/// A single tappable key inside [KeyboardPanel].
///
/// A short tap always inserts a [CharacterKey.base]. When the key also
/// carries [CharacterKey.diacritics], a long-press additionally reports drag
/// progress to the owning row via [onDiacriticStart]/[onDiacriticDragUpdate],
/// so the row can render and resolve its own (possibly multi-row) picker
/// popup - both gestures coexist on the same [GestureDetector] without
/// conflict, since Flutter's gesture arena already arbitrates tap vs.
/// long-press on a single pointer.
class KeyboardKey extends StatefulWidget {
  const KeyboardKey({
    required this.entry,
    this.onDiacriticStart,
    this.onDiacriticDragUpdate,
    this.onDiacriticCommit,
    this.onDiacriticCancel,
    super.key,
  });

  final KeyboardEntry entry;
  final VoidCallback? onDiacriticStart;
  final ValueChanged<Offset>? onDiacriticDragUpdate;
  final VoidCallback? onDiacriticCommit;
  final VoidCallback? onDiacriticCancel;

  @override
  State<KeyboardKey> createState() => _KeyboardKeyState();
}

class _KeyboardKeyState extends State<KeyboardKey> {
  bool _isPressed = false;

  Timer? _backspaceHoldTimer;
  Timer? _backspaceRepeatTimer;

  static const Duration _backspaceHoldDelay = Duration(milliseconds: 500);
  static const Duration _backspaceRepeatInterval = Duration(milliseconds: 80);

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
    }
  }

  void _startBackspaceHold(OnScreenKeyboardController controller) {
    controller.backspace();
    _backspaceHoldTimer = Timer(_backspaceHoldDelay, () {
      _backspaceRepeatTimer = Timer.periodic(
          _backspaceRepeatInterval, (_) => controller.backspace());
    });
  }

  void _stopBackspaceHold() {
    _backspaceHoldTimer?.cancel();
    _backspaceHoldTimer = null;
    _backspaceRepeatTimer?.cancel();
    _backspaceRepeatTimer = null;
  }

  @override
  void dispose() {
    _stopBackspaceHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = OnScreenKeyboardScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;

    return switch (entry) {
      CharacterKey() => _buildCharacterKey(context, controller, entry),
      BackspaceKey() => _buildBackspaceKey(controller, l10n),
      ShiftKey() => _buildActionKey(
          icon: Icons.arrow_upward,
          semanticLabel: l10n.text(AppTextKey.keyboardShiftSemantic),
          onTap: controller.toggleShift,
          isActive: controller.isShifted,
        ),
      LayerToggleKey() => _buildActionKey(
          label: controller.layer == KeyboardLayer.letters
              ? l10n.text(AppTextKey.keyboardNumbersLayerLabel)
              : l10n.text(AppTextKey.keyboardLettersLayerLabel),
          semanticLabel: controller.layer == KeyboardLayer.letters
              ? l10n.text(AppTextKey.keyboardNumbersLayerSemantic)
              : l10n.text(AppTextKey.keyboardLettersLayerSemantic),
          onTap: controller.toggleLayer,
        ),
      SpaceKey() => _buildActionKey(
          semanticLabel: l10n.text(AppTextKey.keyboardSpaceSemantic),
          onTap: () => controller.insertCharacter(' '),
        ),
      DoneKey() => _buildDoneKey(controller, l10n),
    };
  }

  Widget _buildCharacterKey(
    BuildContext context,
    OnScreenKeyboardController controller,
    CharacterKey entry,
  ) {
    final l10n = AppLocalizations.of(context);
    final label = controller.isShifted ? entry.base.toUpperCase() : entry.base;
    final semanticLabel = entry.hasDiacritics
        ? l10n.keyboardDiacriticOptionsSemantic(entry.base)
        : label;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () => controller.insertCharacter(entry.base),
        onLongPressStart:
            entry.hasDiacritics ? (_) => widget.onDiacriticStart?.call() : null,
        onLongPressMoveUpdate: entry.hasDiacritics
            ? (details) =>
                widget.onDiacriticDragUpdate?.call(details.localPosition)
            : null,
        onLongPressEnd: entry.hasDiacritics
            ? (_) {
                _setPressed(false);
                widget.onDiacriticCommit?.call();
              }
            : null,
        onLongPressCancel: entry.hasDiacritics
            ? () {
                _setPressed(false);
                widget.onDiacriticCancel?.call();
              }
            : null,
        child: _KeyTile(
            isPressed: _isPressed, child: Text(label, style: _keyTextStyle)),
      ),
    );
  }

  Widget _buildBackspaceKey(
      OnScreenKeyboardController controller, AppLocalizations l10n) {
    final semanticLabel = l10n.text(AppTextKey.keyboardBackspaceSemantic);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Deletes on press-down (not a completed tap) so a held press can
        // start repeating without double-deleting on release - matches
        // standard keyboard "typematic" repeat behavior.
        onTapDown: (_) {
          _setPressed(true);
          _startBackspaceHold(controller);
        },
        onTapUp: (_) {
          _setPressed(false);
          _stopBackspaceHold();
        },
        onTapCancel: () {
          _setPressed(false);
          _stopBackspaceHold();
        },
        child: _KeyTile(
          isPressed: _isPressed,
          child: const Icon(Icons.backspace_outlined,
              size: 20, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    IconData? icon,
    String? label,
    required String semanticLabel,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: onTap,
        child: _KeyTile(
          isPressed: _isPressed,
          isActive: isActive,
          child: icon != null
              ? Icon(icon,
                  size: 20,
                  color:
                      isActive ? AppColors.primary : AppColors.onSurfaceVariant)
              : (label != null ? Text(label, style: _labelTextStyle) : null),
        ),
      ),
    );
  }

  Widget _buildDoneKey(
      OnScreenKeyboardController controller, AppLocalizations l10n) {
    final label = l10n.text(AppTextKey.keyboardDoneAction);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: controller.submit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: _isPressed ? 0.75 : 1),
                AppColors.primaryFixed.withValues(alpha: _isPressed ? 0.75 : 1),
              ],
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: _labelTextStyle.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // decoration explicitly cleared: Text merges an unset field from the
  // ambient DefaultTextStyle, so leaving it out risks silently inheriting
  // whatever decoration a surrounding theme happens to carry.
  static const TextStyle _keyTextStyle = TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: AppTextStyles.fontFamilyFallback,
    fontSize: 20,
    color: AppColors.onSurface,
    decoration: TextDecoration.none,
  );

  // A literal const (not AppTextStyles.labelLarge.copyWith(...)) so this
  // can never end up a stale `static final` value across a hot reload -
  // Dart hot reload doesn't reliably re-run static field initializers.
  static const TextStyle _labelTextStyle = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: AppTextStyles.fontFamilyFallback,
    fontSize: 14,
    color: AppColors.onSurfaceVariant,
    decoration: TextDecoration.none,
  );
}

/// Shared background/press-feedback chrome for every key variant.
class _KeyTile extends StatelessWidget {
  const _KeyTile(
      {required this.child, this.isPressed = false, this.isActive = false});

  final Widget? child;
  final bool isPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final background = isActive
        ? AppColors.primary20
        : (isPressed
            ? AppColors.surfaceContainerHighest
            : AppColors.surfaceContainerHigh);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
