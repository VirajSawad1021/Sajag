import 'package:flutter/material.dart';

import '../l10n.dart';
import '../speech.dart';
import '../theme.dart';
import 'common.dart';

/// "Read aloud" pill. Shows "Stop" while speaking. [ne]/[en] are built lazily when tapped.
class SpeakButton extends StatelessWidget {
  const SpeakButton({super.key, required this.id, required this.text, this.primary = false});
  final String id;
  final ({String ne, String en}) Function() text;
  final bool primary;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: speaker,
        builder: (context, _) {
          final speaking = speaker.speakingKey == id;
          return Semantics(
            button: true,
            label: speaking ? tr('stopReading') : tr('readAloud'),
            excludeSemantics: true,
            onTap: () => _go(context),
            child: Pill(
              speaking ? tr('stopReading') : tr('readAloud'),
              primary: primary,
              icon: speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              onTap: () => _go(context),
            ),
          );
        },
      );

  Future<void> _go(BuildContext context) async {
    final t = text();
    final ok = await speaker.speak(id, ne: t.ne, en: t.en);
    if (!ok && context.mounted) toast(context, tr('noNepaliVoice'));
  }
}

/// Small speaker icon for a single item (e.g. one warning or one step).
class SpeakIcon extends StatelessWidget {
  const SpeakIcon({super.key, required this.id, required this.ne, required this.en});
  final String id, ne, en;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: speaker,
        builder: (context, _) => IconButton(
          tooltip: tr('readAloud'),
          visualDensity: VisualDensity.compact,
          icon: Icon(speaker.speakingKey == id ? Icons.stop_circle_outlined : Icons.volume_up_outlined, color: C.ink2, size: 20),
          onPressed: () async {
            final ok = await speaker.speak(id, ne: ne, en: en);
            if (!ok && context.mounted) toast(context, tr('noNepaliVoice'));
          },
        ),
      );
}
