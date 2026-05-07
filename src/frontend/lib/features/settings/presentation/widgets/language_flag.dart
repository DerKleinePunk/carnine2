import 'package:carnine_frontend/l10n/app_language_option.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Small painted flag badge that avoids relying on platform emoji fonts.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({
    required this.flag,
    super.key,
  });

  final AppLanguageFlag flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: CustomPaint(
          painter: _LanguageFlagPainter(flag),
        ),
      ),
    );
  }
}

class _LanguageFlagPainter extends CustomPainter {
  const _LanguageFlagPainter(this.flag);

  final AppLanguageFlag flag;

  @override
  void paint(Canvas canvas, Size size) {
    switch (flag) {
      case AppLanguageFlag.germany:
        _paintHorizontalTricolor(
          canvas,
          size,
          const [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)],
        );
      case AppLanguageFlag.unitedKingdom:
        _paintUnionJack(canvas, size);
      case AppLanguageFlag.france:
        _paintVerticalTricolor(
          canvas,
          size,
          const [Color(0xFF0055A4), Color(0xFFFFFFFF), Color(0xFFEF4135)],
        );
      case AppLanguageFlag.spain:
        _paintSpain(canvas, size);
      case AppLanguageFlag.italy:
        _paintVerticalTricolor(
          canvas,
          size,
          const [Color(0xFF009246), Color(0xFFFFFFFF), Color(0xFFCE2B37)],
        );
      case AppLanguageFlag.china:
        _paintChina(canvas, size);
      case AppLanguageFlag.japan:
        _paintJapan(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_LanguageFlagPainter oldDelegate) {
    return oldDelegate.flag != flag;
  }

  void _paintHorizontalTricolor(
    Canvas canvas,
    Size size,
    List<Color> colors,
  ) {
    final stripeHeight = size.height / colors.length;

    for (final entry in colors.indexed) {
      _paintRect(
        canvas,
        Rect.fromLTWH(0, stripeHeight * entry.$1, size.width, stripeHeight),
        entry.$2,
      );
    }
  }

  void _paintVerticalTricolor(Canvas canvas, Size size, List<Color> colors) {
    final stripeWidth = size.width / colors.length;

    for (final entry in colors.indexed) {
      _paintRect(
        canvas,
        Rect.fromLTWH(stripeWidth * entry.$1, 0, stripeWidth, size.height),
        entry.$2,
      );
    }
  }

  void _paintSpain(Canvas canvas, Size size) {
    _paintRect(canvas, Offset.zero & size, const Color(0xFFC60B1E));
    _paintRect(
      canvas,
      Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.5),
      const Color(0xFFFFC400),
    );
  }

  void _paintJapan(Canvas canvas, Size size) {
    _paintRect(canvas, Offset.zero & size, Colors.white);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * 0.26,
      Paint()..color = const Color(0xFFBC002D),
    );
  }

  void _paintChina(Canvas canvas, Size size) {
    _paintRect(canvas, Offset.zero & size, const Color(0xFFDE2910));
    final paint = Paint()..color = const Color(0xFFFFDE00);

    canvas.drawCircle(
        Offset(size.width * 0.25, size.height * 0.32), 3.4, paint);
    canvas.drawCircle(
        Offset(size.width * 0.44, size.height * 0.20), 1.4, paint);
    canvas.drawCircle(
        Offset(size.width * 0.51, size.height * 0.34), 1.4, paint);
    canvas.drawCircle(
        Offset(size.width * 0.49, size.height * 0.50), 1.4, paint);
    canvas.drawCircle(
        Offset(size.width * 0.39, size.height * 0.62), 1.4, paint);
  }

  void _paintUnionJack(Canvas canvas, Size size) {
    _paintRect(canvas, Offset.zero & size, const Color(0xFF012169));

    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final red = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), white)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), white)
      ..drawLine(Offset.zero, Offset(size.width, size.height), red)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), red);

    _paintRect(
      canvas,
      Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.2, size.height),
      Colors.white,
    );
    _paintRect(
      canvas,
      Rect.fromLTWH(0, size.height * 0.38, size.width, size.height * 0.24),
      Colors.white,
    );
    _paintRect(
      canvas,
      Rect.fromLTWH(size.width * 0.44, 0, size.width * 0.12, size.height),
      const Color(0xFFC8102E),
    );
    _paintRect(
      canvas,
      Rect.fromLTWH(0, size.height * 0.43, size.width, size.height * 0.14),
      const Color(0xFFC8102E),
    );
  }

  void _paintRect(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
  }
}
