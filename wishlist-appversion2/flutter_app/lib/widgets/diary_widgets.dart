import 'package:flutter/material.dart';

import '../theme/diary_theme.dart';

class DiaryGridPaper extends StatelessWidget {
  const DiaryGridPaper({
    super.key,
    required this.child,
    this.color = DiaryColors.paper,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 16,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: CustomPaint(
        painter: _GridPainter(color: DiaryColors.grid.withValues(alpha: 0.45)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpiralNotebook extends StatelessWidget {
  const SpiralNotebook({
    super.key,
    required this.child,
    this.folderColor = DiaryColors.folderBlue,
  });

  final Widget child;
  final Color folderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: folderColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: CustomPaint(painter: _SpiralPainter()),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 8, 10, 8),
              child: DiaryGridPaper(
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpiralPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (double y = 16; y < size.height - 8; y += 22) {
      canvas.drawCircle(Offset(size.width / 2, y), 4.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WhiteProductCard extends StatelessWidget {
  const WhiteProductCard({
    super.key,
    required this.child,
    this.indexColor,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final Widget child;
  final Color? indexColor;
  final VoidCallback? onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            if (indexColor != null)
              Container(
                width: 10,
                height: 42,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: indexColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DiaryColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DiaryColors.ink.withValues(alpha: 0.08)),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiaryButton extends StatelessWidget {
  const DiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.color = DiaryColors.folderBlue,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color color;
  final IconData? icon;

  bool get _disabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _disabled ? 0.45 : 1,
      child: Material(
        color: filled ? color : DiaryColors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DiaryColors.ink.withValues(alpha: 0.7), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: DiaryColors.ink),
                  const SizedBox(width: 6),
                ],
                Text(label, style: DiaryTheme.body(13, weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatWon(int price) {
  final s = price.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final reverse = s.length - i;
    buf.write(s[i]);
    if (reverse > 1 && reverse % 3 == 1) buf.write(',');
  }
  return '${buf.toString()}원';
}
