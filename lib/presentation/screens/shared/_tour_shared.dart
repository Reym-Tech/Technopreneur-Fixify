// lib/presentation/screens/shared/_tour_shared.dart
//
// Shared tooltip card used by both the customer and professional first-time
// user tours. Extracted here so both tour_keys files stay lean.
//
// KEY DESIGN — accurate arrow alignment:
//   The package (Showcase.withWidget) places the container widget at a
//   computed offset from the target. The card is 272px wide but may be
//   positioned anywhere horizontally on screen. The arrow must point at
//   the target's horizontal center, not the card's center.
//
//   After the first frame, TourCard reads:
//     • Its own screen X via its own GlobalKey (_cardKey)
//     • The target's screen X via the provided [targetKey]
//   It then sets arrowOffsetX = targetCenterX - cardLeftX, clamped to
//   keep the arrow inside the card boundaries.
//
//   If the keys aren't rendered yet (first frame) the arrow defaults to
//   the card center (size.width / 2), so there's no flash or error.

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const kTourCardWidth = 272.0;
const kTourPrimary = Color(0xFF0F3D2E);
const kTourTitleColor = Color(0xFF0F3D2E);
const kTourBodyColor = Color(0xFF4A5568);
const kTourCardBg = Colors.white;
const kTourBorderColor = Color(0xFFD0E4DC);
const kTourButtonBg = Color(0xFFF0F7F4);
const kTourRadius = 14.0;
const kTourArrowW = 18.0;
const kTourArrowH = 10.0;
const kTourBorderW = 1.2;

// ── Arrow direction ───────────────────────────────────────────────────────────

enum TourArrowDir { up, down }

// ── Card + Arrow painter ──────────────────────────────────────────────────────

class TourCardPainter extends CustomPainter {
  final TourArrowDir dir;

  /// Horizontal center of the arrow tip, measured from the card's left edge.
  /// Defaults to card center when target position is not yet known.
  final double arrowOffsetX;

  const TourCardPainter({required this.dir, required this.arrowOffsetX});

  @override
  void paint(Canvas canvas, Size size) {
    final r = kTourRadius;
    final aW = kTourArrowW;
    final aH = kTourArrowH;
    // Clamp arrow so its base always fits within the rounded corners.
    final cx = arrowOffsetX.clamp(r + aW / 2, size.width - r - aW / 2);

    final cardTop = dir == TourArrowDir.up ? aH : 0.0;
    final cardBottom =
        dir == TourArrowDir.down ? size.height - aH : size.height;

    final path = Path();

    if (dir == TourArrowDir.up) {
      path.moveTo(cx - aW / 2, cardTop);
      path.lineTo(cx, 0);
      path.lineTo(cx + aW / 2, cardTop);
      path.lineTo(size.width - r, cardTop);
      path.arcToPoint(Offset(size.width, cardTop + r),
          radius: const Radius.circular(kTourRadius));
      path.lineTo(size.width, cardBottom - r);
      path.arcToPoint(Offset(size.width - r, cardBottom),
          radius: const Radius.circular(kTourRadius));
      path.lineTo(r, cardBottom);
      path.arcToPoint(Offset(0, cardBottom - r),
          radius: const Radius.circular(kTourRadius));
      path.lineTo(0, cardTop + r);
      path.arcToPoint(Offset(r, cardTop),
          radius: const Radius.circular(kTourRadius));
      path.close();
    } else {
      path.moveTo(r, 0);
      path.lineTo(size.width - r, 0);
      path.arcToPoint(Offset(size.width, r),
          radius: const Radius.circular(kTourRadius));
      path.lineTo(size.width, cardBottom - r);
      path.arcToPoint(Offset(size.width - r, cardBottom),
          radius: const Radius.circular(kTourRadius));
      path.lineTo(cx + aW / 2, cardBottom);
      path.lineTo(cx, size.height);
      path.lineTo(cx - aW / 2, cardBottom);
      path.lineTo(r, cardBottom);
      path.arcToPoint(Offset(0, cardBottom - r),
          radius: const Radius.circular(kTourRadius));
      path.lineTo(0, r);
      path.arcToPoint(Offset(r, 0), radius: const Radius.circular(kTourRadius));
      path.close();
    }

    // 1. Fill
    canvas.drawPath(
        path,
        Paint()
          ..color = kTourCardBg
          ..style = PaintingStyle.fill);
    // 2. Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.11), 8, false);
    // 3. Border (on top of fill)
    canvas.drawPath(
        path,
        Paint()
          ..color = kTourBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = kTourBorderW);
  }

  @override
  bool shouldRepaint(TourCardPainter old) =>
      old.dir != dir || old.arrowOffsetX != arrowOffsetX;
}

// ── Tour card widget ──────────────────────────────────────────────────────────

class TourCard extends StatefulWidget {
  final String title;
  final String description;
  final bool isLast;
  final TourArrowDir arrowDir;
  final BuildContext showcaseContext;

  /// GlobalKey of the Showcase target widget — used to compute the accurate
  /// horizontal arrow offset after the first frame.
  /// A GlobalKey attached directly to the visible child widget (not the
  /// Showcase wrapper). Used to measure the child's actual screen position
  /// for accurate arrow alignment.
  final GlobalKey innerKey;

  const TourCard({
    super.key,
    required this.title,
    required this.description,
    required this.isLast,
    required this.arrowDir,
    required this.showcaseContext,
    required this.innerKey,
  });

  @override
  State<TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<TourCard> {
  final _cardKey = GlobalKey();
  double _arrowOffsetX = kTourCardWidth / 2; // default: centered

  @override
  void initState() {
    super.initState();
    // After the first frame, compute the accurate arrow X.
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeArrowOffset());
  }

  void _computeArrowOffset() {
    if (!mounted) return;
    try {
      final cardBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      final targetBox =
          widget.innerKey.currentContext?.findRenderObject() as RenderBox?;
      if (cardBox == null || targetBox == null) return;

      final cardPos = cardBox.localToGlobal(Offset.zero);
      final targetPos = targetBox.localToGlobal(Offset.zero);
      final targetCenterX = targetPos.dx + targetBox.size.width / 2;
      final arrowX = targetCenterX - cardPos.dx;

      if (mounted && (arrowX - _arrowOffsetX).abs() > 1.0) {
        setState(() => _arrowOffsetX = arrowX);
      }
    } catch (_) {
      // If layout isn't ready, keep the default centered position.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _cardKey,
      width: kTourCardWidth,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: TourCardPainter(
                dir: widget.arrowDir,
                arrowOffsetX: _arrowOffsetX,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: widget.arrowDir == TourArrowDir.up ? kTourArrowH + 14 : 14,
              bottom:
                  widget.arrowDir == TourArrowDir.down ? kTourArrowH + 12 : 12,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTourTitleColor,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTourBodyColor,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: const Color(0xFFEEEEEE)),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.isLast) {
                        ShowCaseWidget.of(widget.showcaseContext).dismiss();
                      } else {
                        ShowCaseWidget.of(widget.showcaseContext).next();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: kTourButtonBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.isLast ? 'Done' : 'Next',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTourPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
