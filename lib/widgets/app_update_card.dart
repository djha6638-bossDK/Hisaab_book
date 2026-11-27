import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import 'app_shell.dart';

class AppUpdateCard extends StatelessWidget {
  const AppUpdateCard({
    required this.update,
    required this.downloading,
    required this.progress,
    required this.onUpdate,
    required this.onDismiss,
    super.key,
  });

  final AppUpdateInfo update;
  final bool downloading;
  final double progress;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final percent = (clampedProgress * 100).round();
    return AppSurface(
      key: const ValueKey<String>('app-update-card'),
      color: const Color(0xffeef2ff),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.system_update_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Naya update aa gaya hai',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Version ${update.displayVersion} ready hai. '
                      'Neeche se update kar lo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (update.releaseNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              update.releaseNotes,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (downloading) ...<Widget>[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              key: const ValueKey<String>('update-progress'),
              value: clampedProgress,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(
              percent >= 100
                  ? 'Download poora hua. Installer khul raha hai...'
                  : '$percent% download ho gaya. Kuch der ruko.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final updateButton = FilledButton.icon(
                  key: const ValueKey<String>('update-now-button'),
                  onPressed: onUpdate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Update karo'),
                );
                final laterButton = OutlinedButton(
                  key: const ValueKey<String>('update-later-button'),
                  onPressed: onDismiss,
                  child: const Text('Baad me'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      updateButton,
                      const SizedBox(height: 8),
                      laterButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: updateButton),
                    const SizedBox(width: 10),
                    Expanded(child: laterButton),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
