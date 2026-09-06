import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Static UI preview of the maps/navigation tab, based on the 1024x600
/// Stitch navigation template (`docs/stitch_car_pc/carnine_navigation_1024x600`).
///
/// This is presentation only - no routing, search, or gRPC wiring yet. The
/// map itself is a decorative local pattern rather than a loaded image,
/// since the app never depends on network access for its UI
/// (`docs/02-constraints.md`).
class MapsContent extends StatelessWidget {
  const MapsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        _MapBackground(),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(child: _DestinationSearchBar()),
        ),
        Positioned(top: 16, left: 24, child: _TurnByTurnCard()),
        Positioned(
          right: 24,
          top: 0,
          bottom: 0,
          child: Center(child: _ZoomControls()),
        ),
        Positioned(left: 24, right: 24, bottom: 20, child: _TripStatusBar()),
      ],
    );
  }
}

/// Decorative city-grid pattern standing in for a real map tile until
/// routing/rendering is wired up.
class _MapBackground extends StatelessWidget {
  const _MapBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: CustomPaint(
        painter: _MapGridPainter(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1,
              colors: [
                AppColors.surface.withValues(alpha: 0),
                AppColors.surface,
              ],
              stops: const [0.4, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  static const double _gridSpacing = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant20
      ..strokeWidth = 1;

    for (
      double x = size.width % _gridSpacing;
      x < size.width;
      x += _gridSpacing
    ) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (
      double y = size.height % _gridSpacing;
      y < size.height;
      y += _gridSpacing
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routeStart = Offset(size.width * 0.12, size.height * 0.85);
    final routeEnd = Offset(size.width * 0.62, size.height * 0.22);
    final routeControl = Offset(size.width * 0.28, size.height * 0.35);
    final routePath = Path()
      ..moveTo(routeStart.dx, routeStart.dy)
      ..quadraticBezierTo(
        routeControl.dx,
        routeControl.dy,
        routeEnd.dx,
        routeEnd.dy,
      );

    canvas.drawPath(
      routePath,
      Paint()
        ..color = AppColors.primary40
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      routePath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(routeStart, 6, Paint()..color = AppColors.onSurface);
    canvas.drawCircle(routeEnd, 8, Paint()..color = AppColors.secondary);
    canvas.drawCircle(
      routeEnd,
      8,
      Paint()
        ..color = AppColors.secondary40
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_MapGridPainter oldDelegate) => false;
}

class _DestinationSearchBar extends StatelessWidget {
  const _DestinationSearchBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: 420,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: AppColors.primary,
            size: 20,
            shadows: [Shadow(color: AppColors.primary40, blurRadius: 8)],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.text(AppTextKey.mapsSearchPlaceholder),
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const Icon(
            Icons.mic_none,
            color: AppColors.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _TurnByTurnCard extends StatelessWidget {
  const _TurnByTurnCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.turn_slight_right,
                color: AppColors.primary,
                size: 36,
                shadows: [Shadow(color: AppColors.primary40, blurRadius: 8)],
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 22,
                  ),
                  children: [
                    const TextSpan(text: '450 '),
                    TextSpan(
                      text: 'm',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text(AppTextKey.mapsNextTurnLabel).toUpperCase(),
            style: AppTextStyles.kineticSubtitle.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Lindenallee',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleIconButton(
          icon: Icons.add,
          semanticLabel: l10n.text(AppTextKey.mapsZoomInSemantic),
          color: AppColors.primary,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _CircleIconButton(
          icon: Icons.remove,
          semanticLabel: l10n.text(AppTextKey.mapsZoomOutSemantic),
          color: AppColors.primary,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        _CircleIconButton(
          icon: Icons.explore,
          semanticLabel: l10n.text(AppTextKey.mapsRecenterSemantic),
          color: AppColors.secondary,
          onTap: () {},
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
  });

  static const double _size = 48;

  final IconData icon;
  final String semanticLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        shape: const CircleBorder(side: BorderSide(color: AppColors.primary20)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary20,
          highlightColor: AppColors.surfaceContainerHighest,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _TripStatusBar extends StatelessWidget {
  const _TripStatusBar();

  static const double _progress = 0.65;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          _TripStat(
            label: l10n.text(AppTextKey.mapsArrivalLabel),
            value: '13:12',
          ),
          const SizedBox(width: 20),
          Container(
            width: 1,
            height: 32,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 20),
          _TripStat(
            label: l10n.text(AppTextKey.mapsDurationLabel),
            value: '24',
            unit: 'min',
            valueColor: AppColors.primary,
          ),
          const SizedBox(width: 28),
          const Expanded(child: _TripProgressTrack(progress: _progress)),
          const SizedBox(width: 28),
          _TripStat(
            label: l10n.text(AppTextKey.mapsDistanceLabel),
            value: '18.4',
            unit: 'km',
            alignEnd: true,
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorContainer,
              foregroundColor: AppColors.onErrorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(l10n.text(AppTextKey.mapsCancelRouteAction)),
          ),
        ],
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  const _TripStat({
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = AppColors.onSurface,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final String? unit;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.kineticSubtitle.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: AppTextStyles.headlineLarge.copyWith(
              color: valueColor,
              fontSize: 22,
              shadows: valueColor == AppColors.primary
                  ? const [Shadow(color: AppColors.primary40, blurRadius: 8)]
                  : null,
            ),
            children: [
              TextSpan(text: value),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w300,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripProgressTrack extends StatelessWidget {
  const _TripProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.surfaceContainerHighest),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        boxShadow: const [
                          BoxShadow(color: AppColors.primary40, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment(progress * 2 - 1, 0),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.white, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
