import 'dart:async';

import 'package:conduit/features/local_shell/domain/local_shell_state.dart';
import 'package:conduit/features/local_shell/domain/rootfs_manifest.dart';
import 'package:conduit/features/local_shell/presentation/local_shell_controller.dart';
import 'package:flutter/material.dart';

class LocalShellPage extends StatefulWidget {
  const LocalShellPage({
    required this.controllers,
    required this.onOpenSession,
    required this.onCloseSession,
    super.key,
  });

  /// One controller per available distro (Arch, Ubuntu, Debian).
  final List<LocalShellController> controllers;

  /// Called when the user wants to open a terminal for [controller]'s distro.
  final Future<void> Function(LocalShellController controller) onOpenSession;

  /// Called before reinstalling/removing to close any open terminal tab for
  /// [controller]'s distro.
  final Future<void> Function(LocalShellController controller) onCloseSession;

  @override
  State<LocalShellPage> createState() => _LocalShellPageState();
}

class _LocalShellPageState extends State<LocalShellPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in widget.controllers) {
        unawaited(c.refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local shell')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < widget.controllers.length; i++) ...[
                _DistroSection(
                  controller: widget.controllers[i],
                  onOpenSession: () => unawaited(
                    widget.onOpenSession(widget.controllers[i]),
                  ),
                  onCloseSession: () =>
                      widget.onCloseSession(widget.controllers[i]),
                ),
                if (i < widget.controllers.length - 1) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 24),
                ],
              ],
              const SizedBox(height: 32),
              const _CreditFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-distro section
// ---------------------------------------------------------------------------

class _DistroSection extends StatefulWidget {
  const _DistroSection({
    required this.controller,
    required this.onOpenSession,
    required this.onCloseSession,
  });

  final LocalShellController controller;
  final VoidCallback onOpenSession;
  final Future<void> Function() onCloseSession;

  @override
  State<_DistroSection> createState() => _DistroSectionState();
}

class _DistroSectionState extends State<_DistroSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        if (state.isUnsupported) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.controller.displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildContent(context, state),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, LocalShellState state) {
    final controller = widget.controller;
    return switch (state.stage) {
      LocalShellStage.checking => const _Checking(),
      LocalShellStage.unsupported => _Unsupported(message: state.error?.message),
      LocalShellStage.notInstalled => _NotInstalled(
          displayName: controller.displayName,
          downloadSizeBytes: controller.downloadSizeBytes,
          packageManager: controller.packageManager,
          onInstall: controller.install,
        ),
      LocalShellStage.downloading ||
      LocalShellStage.extracting ||
      LocalShellStage.configuring => _Installing(
          state: state,
          displayName: controller.displayName,
        ),
      LocalShellStage.failed => _Failed(
          error: state.error,
          onRetry: controller.install,
        ),
      LocalShellStage.ready => _Ready(
          state: state,
          displayName: controller.displayName,
          packageManager: controller.packageManager,
          sharedStorageFeatureEnabled: controller.sharedStorageFeatureEnabled,
          sharedStorageAccessGranted: controller.sharedStorageAccessGranted,
          onOpen: widget.onOpenSession,
          onReinstall: _confirmReinstall,
          onReset: _confirmReset,
        ),
    };
  }

  void _confirmReinstall() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reinstall ${widget.controller.displayName}?'),
        content: const Text(
          'This wipes the current environment — including anything you '
          'installed — and downloads a fresh image. Any open terminal tab '
          'for this distro will be closed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reinstall'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await widget.onCloseSession();
        await widget.controller.reinstall();
      }
    });
  }

  void _confirmReset() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this distro?'),
        content: Text(
          'This deletes the ${widget.controller.displayName} environment '
          'and everything in it. Any open terminal tab will be closed '
          'first. You can reinstall it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await widget.onCloseSession();
        await widget.controller.reset();
      }
    });
  }
}

// ---------------------------------------------------------------------------
// State widgets
// ---------------------------------------------------------------------------

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SizedBox(height: 8), LinearProgressIndicator()],
    );
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _Hero(
      icon: Icons.phonelink_erase_outlined,
      title: 'Not available on this device',
      body:
          message ??
          'The local shell needs a 64-bit ARM (arm64-v8a) Android device.',
    );
  }
}

class _NotInstalled extends StatelessWidget {
  const _NotInstalled({
    required this.displayName,
    required this.downloadSizeBytes,
    required this.packageManager,
    required this.onInstall,
  });

  final String displayName;
  final int downloadSizeBytes;
  final PackageManager packageManager;
  final Future<void> Function() onInstall;

  @override
  Widget build(BuildContext context) {
    final pkgHint =
        packageManager == PackageManager.pacman ? 'pacman' : 'apt-get';
    final sizeMb = (downloadSizeBytes / 1024 / 1024).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          icon: Icons.terminal_rounded,
          title: 'Run $displayName on your device',
          body:
              'Install a full $displayName userland with $pkgHint, running '
              'locally through proot. The image downloads on first use.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onInstall,
          icon: const Icon(Icons.download_rounded),
          label: Text('Install $displayName'),
        ),
        const SizedBox(height: 12),
        Text(
          'Downloads ~$sizeMb MB. Wi-Fi recommended.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Installing extends StatelessWidget {
  const _Installing({required this.state, required this.displayName});

  final LocalShellState state;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          icon: Icons.settings_suggest_outlined,
          title: 'Setting up $displayName',
          body: state.message ?? 'Working…',
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(value: progress),
        if (progress != null) ...[
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});

  final LocalShellError? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          icon: Icons.error_outline_rounded,
          title: _title(error?.kind),
          body: error?.message ?? 'Something went wrong during setup.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }

  String _title(LocalShellErrorKind? kind) {
    return switch (kind) {
      LocalShellErrorKind.network => 'Download failed',
      LocalShellErrorKind.lowDisk => 'Not enough storage',
      LocalShellErrorKind.corruptDownload => 'Download was corrupted',
      LocalShellErrorKind.extractionFailed => 'Could not unpack the image',
      LocalShellErrorKind.keyringFailed => 'Configuration failed',
      LocalShellErrorKind.unsupportedDevice => 'Not available on this device',
      LocalShellErrorKind.unknown || null => 'Setup failed',
    };
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.state,
    required this.displayName,
    required this.packageManager,
    required this.sharedStorageFeatureEnabled,
    required this.sharedStorageAccessGranted,
    required this.onOpen,
    required this.onReinstall,
    required this.onReset,
  });

  final LocalShellState state;
  final String displayName;
  final PackageManager packageManager;
  final bool sharedStorageFeatureEnabled;
  final bool sharedStorageAccessGranted;
  final VoidCallback onOpen;
  final VoidCallback onReinstall;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageStatus = !sharedStorageFeatureEnabled
        ? 'Full build only'
        : sharedStorageAccessGranted
        ? '/mnt/android'
        : 'Permission needed';
    final storageHint = sharedStorageFeatureEnabled
        ? 'Grant file access to mount phone storage at /mnt/android.'
        : 'Phone storage mounting is available in the full build.';
    final pkgCmd = packageManager == PackageManager.pacman
        ? 'pacman -Syu'
        : 'apt-get update && apt-get upgrade';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          icon: Icons.check_circle_outline_rounded,
          title: '$displayName is ready',
          body:
              'Open a local shell and use '
              '${packageManager == PackageManager.pacman ? 'pacman' : 'apt-get'} '
              'like any other terminal.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.terminal_rounded),
          label: const Text('Open shell'),
        ),
        const SizedBox(height: 24),
        _InfoRow(label: 'Version', value: state.installedVersion ?? 'unknown'),
        _InfoRow(
          label: 'Disk usage',
          value: _formatBytes(state.diskUsageBytes),
        ),
        _InfoRow(label: 'Android files', value: storageStatus),
        const SizedBox(height: 16),
        Text(
          'Update packages from inside the shell with  $pkgCmd . $storageHint',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onReinstall,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reinstall'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onReset,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Remove'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 40, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CreditFooter extends StatelessWidget {
  const _CreditFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 8),
        Text(
          'The local shell uses proot with Linux distribution images packaged '
          'through Termux proot-distro. Conduit redistributes the bundled '
          'tools under their own open-source licenses.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                showLicensePage(context: context, applicationName: 'Conduit'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text('Open-source licenses'),
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'unknown';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final fixed = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$fixed ${units[unit]}';
}
