import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

import 'keyboard_key.dart';
import 'keyboard_layout.dart';
import 'on_screen_keyboard_scope.dart';

/// Height of a single key row, including its own [KeyboardKey] margin.
const double keyRowHeight = 66;

/// Diacritic popups wrap to a new row above this many alternates (e.g. 'o'
/// has 8: the base letter plus 7 accents) - a single row that long would
/// run off the right edge of the screen for a key near it.
const int _maxDiacriticColumns = 4;

int _diacriticColumnsFor(int alternateCount) =>
    alternateCount < _maxDiacriticColumns
        ? alternateCount
        : _maxDiacriticColumns;

/// Renders the currently active layer's key grid plus the shared bottom
/// row, and hosts each row's own diacritic picker popup.
class KeyboardPanel extends StatelessWidget {
  const KeyboardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OnScreenKeyboardScope.of(context);
    final rows = controller.layer == KeyboardLayer.letters
        ? KeyboardLayouts.letters
        : KeyboardLayouts.numbersSymbols;
    final maxFlexSum = <List<KeyboardEntry>>[...rows, KeyboardLayouts.bottomRow]
        .map(_flexSumOf)
        .reduce((a, b) => a > b ? a : b);

    return TapRegion(
      // Joins the same implicit group TextField's own TextFieldTapRegion
      // uses by default (see EditableText/TextFieldTapRegion), so a key tap
      // counts as "inside" the focused OnScreenTextField's region instead of
      // outside it - the field only unfocuses (and the panel closes) on a
      // tap that lands on neither the field nor the keyboard.
      groupId: EditableText,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                _KeyboardRow(entries: row, maxFlexSum: maxFlexSum),
              _KeyboardRow(
                  entries: KeyboardLayouts.bottomRow, maxFlexSum: maxFlexSum),
            ],
          ),
        ),
      ),
    );
  }

  static int _flexSumOf(List<KeyboardEntry> row) =>
      row.fold(0, (sum, entry) => sum + entry.flex);
}

/// One row of keys, centered under [maxFlexSum] flex units so shorter rows
/// (e.g. the "a s d f..." row) line up visually under the widest row.
class _KeyboardRow extends StatefulWidget {
  const _KeyboardRow({required this.entries, required this.maxFlexSum});

  final List<KeyboardEntry> entries;
  final int maxFlexSum;

  @override
  State<_KeyboardRow> createState() => _KeyboardRowState();
}

class _KeyboardRowState extends State<_KeyboardRow> {
  int? _activeColumnIndex;
  double _activeKeyWidth = 0;
  int _highlightedIndex = 0;

  CharacterKey get _activeKey =>
      widget.entries[_activeColumnIndex!] as CharacterKey;

  void _startDiacritic(int columnIndex, double keyWidth) {
    setState(() {
      _activeColumnIndex = columnIndex;
      _activeKeyWidth = keyWidth;
      _highlightedIndex = 0;
    });
  }

  /// [localPosition] is relative to the pressed key's own box (top-left at
  /// the key's origin) - negative `dy` means the finger has moved above the
  /// key, into the popup.
  void _updateDiacriticDrag(Offset localPosition) {
    final alternates = <String>[_activeKey.base, ..._activeKey.diacritics!];
    final columns = _diacriticColumnsFor(alternates.length);
    final totalRows = (alternates.length / columns).ceil();

    final column =
        (localPosition.dx / _activeKeyWidth).floor().clamp(0, columns - 1);
    // Row 0 = the row closest to the key (least upward movement needed).
    final rowFromKey =
        (-localPosition.dy / keyRowHeight).floor().clamp(0, totalRows - 1);
    final rowFromTop = totalRows - 1 - rowFromKey;
    final index =
        (rowFromTop * columns + column).clamp(0, alternates.length - 1);

    if (index != _highlightedIndex) {
      setState(() => _highlightedIndex = index);
    }
  }

  void _commitDiacritic(BuildContext context) {
    final alternates = <String>[_activeKey.base, ..._activeKey.diacritics!];
    OnScreenKeyboardScope.of(context)
        .insertCharacter(alternates[_highlightedIndex]);
    setState(() => _activeColumnIndex = null);
  }

  void _cancelDiacritic() {
    setState(() => _activeColumnIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final flexSum = widget.entries.fold(0, (sum, entry) => sum + entry.flex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final unitWidth = constraints.maxWidth / widget.maxFlexSum;
        final rowWidth = unitWidth * flexSum;
        final activeColumnIndex = _activeColumnIndex;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: keyRowHeight,
              child: Center(
                child: SizedBox(
                  width: rowWidth,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.entries.length; i++)
                        SizedBox(
                          width: unitWidth * widget.entries[i].flex,
                          height: keyRowHeight,
                          child: _keyFor(i, unitWidth * widget.entries[i].flex),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (activeColumnIndex != null)
              _positionedDiacriticPopup(
                  constraints, rowWidth, activeColumnIndex),
          ],
        );
      },
    );
  }

  Widget _positionedDiacriticPopup(
    BoxConstraints constraints,
    double rowWidth,
    int activeColumnIndex,
  ) {
    final alternates = <String>[_activeKey.base, ..._activeKey.diacritics!];
    final columns = _diacriticColumnsFor(alternates.length);
    // +8 for _DiacriticPopup's own EdgeInsets.all(4) padding on each side.
    final popupWidth = columns * _activeKeyWidth + 8;
    final maxLeft = constraints.maxWidth - popupWidth < 0
        ? 0.0
        : constraints.maxWidth - popupWidth;
    final unitWidth = constraints.maxWidth / widget.maxFlexSum;
    final rawLeft = (constraints.maxWidth - rowWidth) / 2 +
        unitWidth *
            widget.entries
                .sublist(0, activeColumnIndex)
                .fold<int>(0, (sum, entry) => sum + entry.flex);

    return Positioned(
      bottom: keyRowHeight,
      left: rawLeft.clamp(0.0, maxLeft),
      child: _DiacriticPopup(
        base: _activeKey.base,
        diacritics: _activeKey.diacritics!,
        highlightedIndex: _highlightedIndex,
        keyWidth: _activeKeyWidth,
      ),
    );
  }

  Widget _keyFor(int index, double keyWidth) {
    final entry = widget.entries[index];
    if (entry is! CharacterKey || !entry.hasDiacritics) {
      return KeyboardKey(entry: entry);
    }

    return Builder(
      builder: (context) => KeyboardKey(
        entry: entry,
        onDiacriticStart: () => _startDiacritic(index, keyWidth),
        onDiacriticDragUpdate: _updateDiacriticDrag,
        onDiacriticCommit: () => _commitDiacritic(context),
        onDiacriticCancel: _cancelDiacritic,
      ),
    );
  }
}

/// Small grid of alternates shown above a long-pressed diacritic key,
/// wrapping to further rows above [_maxDiacriticColumns] entries so it never
/// runs off the side of the screen, fading and scaling in over the panel's
/// ≤200ms motion budget.
class _DiacriticPopup extends StatelessWidget {
  const _DiacriticPopup({
    required this.base,
    required this.diacritics,
    required this.highlightedIndex,
    required this.keyWidth,
  });

  final String base;
  final List<String> diacritics;
  final int highlightedIndex;
  final double keyWidth;

  @override
  Widget build(BuildContext context) {
    final alternates = <String>[base, ...diacritics];
    final columns = _diacriticColumnsFor(alternates.length);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.85 + 0.15 * progress,
          alignment: Alignment.bottomLeft,
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: columns * keyWidth),
            child: Wrap(
              children: [
                for (var i = 0; i < alternates.length; i++)
                  Container(
                    width: keyWidth,
                    height: keyRowHeight - 8,
                    alignment: Alignment.center,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                    decoration: BoxDecoration(
                      color: i == highlightedIndex
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alternates[i],
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: i == highlightedIndex
                            ? AppColors.onPrimary
                            : AppColors.onSurface,
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
