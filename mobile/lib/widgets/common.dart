import 'package:flutter/material.dart';

import '../theme.dart';

/// Black pill CTA (primary) or light pill (secondary), as in the InstaJob design system.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.onTap, this.icon, this.primary = true, this.big = false, this.busy = false, this.danger = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary, big, busy, danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? C.high : (primary ? C.ink : C.raised);
    final fg = primary || danger ? Colors.white : C.ink;
    return Material(
      color: onTap == null ? bg.withValues(alpha: 0.4) : bg,
      shape: StadiumBorder(side: primary || danger ? BorderSide.none : const BorderSide(color: C.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: big ? 22 : 16, vertical: big ? 15 : 10),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            else if (icon != null)
              Icon(icon, size: big ? 20 : 17, color: fg),
            if (busy || icon != null) const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: T.pill.copyWith(color: fg, fontSize: big ? 15 : 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// #FAFAFA module with a hairline border and 24px corners.
class Module extends StatelessWidget {
  const Module({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color, borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? C.module,
          borderRadius: BorderRadius.circular(R.section),
          border: Border.all(color: borderColor ?? C.border),
        ),
        child: child,
      );
}

/// White card nested inside a module.
class RaisedCard extends StatelessWidget {
  const RaisedCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.accent});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Material(
        color: C.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.card),
          side: BorderSide(color: accent ?? C.border, width: accent == null ? 1 : 1.4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(R.card),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.fg = C.ink2, this.bg = C.pill, this.icon});
  final String text;
  final Color fg, bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: T.pill.copyWith(color: fg, fontSize: 11.5)),
        ]),
      );
}

/// Painterly artwork panel (InstaJob's art) with content on a white sheet on top.
class ArtPanel extends StatelessWidget {
  const ArtPanel({super.key, required this.art, required this.child, this.height});
  final String art;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(R.section),
        child: Stack(children: [
          Positioned.fill(child: Image.asset('assets/art/$art', fit: BoxFit.cover)),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});
  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 19, color: C.ink), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: T.h2)),
          ?trailing,
        ]),
      );
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
