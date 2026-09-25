import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:local_map/local_map.dart';

/// Destination search on the on-screen keyboard, with the hits below.
///
/// Owns its [TextEditingController] so the page's 1 Hz rebuilds (position
/// updates) never reset the text. The microphone of the template is left
/// out until there is voice input.
class DestinationSearch extends StatefulWidget {
  const DestinationSearch({
    required this.results,
    required this.searching,
    required this.onChanged,
    required this.onSelected,
    this.message,
    super.key,
  });

  final List<GeocoderResult> results;
  final bool searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<GeocoderResult> onSelected;

  /// Shown under the field instead of hits, e.g. "no results".
  final String? message;

  @override
  State<DestinationSearch> createState() => _DestinationSearchState();
}

class _DestinationSearchState extends State<DestinationSearch> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _select(GeocoderResult place) {
    _text.text = place.name;
    FocusScope.of(context).unfocus();
    widget.onSelected(place);
  }

  void _clear() {
    _text.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: _fieldDecoration,
            child: OnScreenTextField(
              controller: _text,
              onChanged: widget.onChanged,
              semanticLabel: l10n.text(AppTextKey.mapsSearchSemantic),
              hintText: l10n.text(AppTextKey.mapsSearchPlaceholder),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _clearButton(l10n),
            ),
          ),
          if (widget.searching ||
              widget.results.isNotEmpty ||
              widget.message != null)
            _Results(
              results: widget.results,
              searching: widget.searching,
              message: widget.message,
              onSelected: _select,
            ),
        ],
      ),
    );
  }

  Widget _clearButton(AppLocalizations l10n) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _text,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: l10n.text(AppTextKey.mapsSearchClearSemantic),
          icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
          onPressed: _clear,
        );
      },
    );
  }

  static final _fieldDecoration = BoxDecoration(
    color: AppColors.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: AppColors.primary20),
    boxShadow: const [
      BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
    ],
  );
}

class _Results extends StatelessWidget {
  const _Results({
    required this.results,
    required this.searching,
    required this.message,
    required this.onSelected,
  });

  /// Rows at the in-vehicle touch minimum.
  static const double _rowHeight = 76;

  final List<GeocoderResult> results;
  final bool searching;
  final String? message;
  final ValueChanged<GeocoderResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: _rowHeight * 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _content(),
    );
  }

  Widget _content() {
    if (searching && results.isEmpty) {
      return const SizedBox(
        height: _rowHeight,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final text = message;
    if (results.isEmpty && text != null) {
      return SizedBox(
        height: _rowHeight,
        child: Center(
          child: Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemExtent: _rowHeight,
      itemCount: results.length,
      itemBuilder: (context, i) =>
          _ResultRow(place: results[i], onTap: () => onSelected(results[i])),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.place, required this.onTap});

  final GeocoderResult place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = place.detail;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(_icon(place.type), color: AppColors.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
    'poi' => Icons.place,
    'mountain_peak' => Icons.terrain,
    'water_name' => Icons.water,
    'transportation_name' => Icons.add_road,
    _ => Icons.location_city,
  };
}
