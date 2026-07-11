import 'package:conduit/features/local_shell/domain/rootfs_manifest.dart';

class FirstBootConfig {
  const FirstBootConfig({
    required this.packageManager,
    required this.doneMarkerPath,
    this.pacmanMirror = '',
    this.keyringName = 'archlinuxarm',
    this.nameservers = const ['1.1.1.1', '8.8.8.8'],
    this.locales = const ['en_US.UTF-8 UTF-8', 'C.UTF-8 UTF-8'],
    this.defaultLocale = 'en_US.UTF-8',
  });

  final PackageManager packageManager;
  final String doneMarkerPath;
  final String pacmanMirror;
  final String keyringName;
  final List<String> nameservers;
  final List<String> locales;
  final String defaultLocale;
}

class FirstBootScript {
  const FirstBootScript();

  String generate(FirstBootConfig config) {
    final buffer = StringBuffer()
      ..writeln('#!/bin/bash')
      ..writeln('set -euo pipefail')
      ..writeln()
      ..writeln('# Idempotent: bail out if first boot already completed.')
      ..writeln('if [ -f "${config.doneMarkerPath}" ]; then')
      ..writeln('  exit 0')
      ..writeln('fi')
      ..writeln()
      ..writeln('# --- DNS resolution ---')
      ..writeln('rm -f /etc/resolv.conf');
    for (final nameserver in config.nameservers) {
      buffer.writeln('echo "nameserver $nameserver" >> /etc/resolv.conf');
    }
    buffer
      ..writeln()
      ..writeln('# --- hosts ---')
      ..writeln('cat > /etc/hosts <<EOF')
      ..writeln('127.0.0.1 localhost')
      ..writeln('::1 localhost')
      ..writeln('EOF');

    switch (config.packageManager) {
      case PackageManager.pacman:
        _writePacmanSetup(buffer, config);
      case PackageManager.apt:
        _writeAptSetup(buffer, config);
    }

    _writeSystemctlShim(buffer);
    _writeFirstLoginWelcome(buffer, config);
    _writeDoneMarker(buffer, config);

    return buffer.toString();
  }

  void _writePacmanSetup(StringBuffer buffer, FirstBootConfig config) {
    buffer
      ..writeln()
      ..writeln('# --- pacman mirror ---')
      ..writeln('mkdir -p /etc/pacman.d')
      ..writeln(
        "echo 'Server = ${config.pacmanMirror}' > /etc/pacman.d/mirrorlist",
      )
      ..writeln()
      ..writeln('# --- locale ---');
    for (final locale in config.locales) {
      buffer.writeln("echo '$locale' >> /etc/locale.gen");
    }
    buffer
      ..writeln('locale-gen')
      ..writeln("echo 'LANG=${config.defaultLocale}' > /etc/locale.conf")
      ..writeln()
      ..writeln('# --- entropy seed (keeps pacman-key from blocking) ---')
      ..writeln('mkdir -p /var/lib')
      ..writeln('head -c 4096 /dev/urandom > /root/.rnd 2>/dev/null || true')
      ..writeln()
      ..writeln('# --- pacman keyring ---')
      ..writeln('pacman-key --init')
      ..writeln('pacman-key --populate ${config.keyringName}');
  }

  void _writeAptSetup(StringBuffer buffer, FirstBootConfig config) {
    buffer
      ..writeln()
      ..writeln('# --- locale ---')
      ..writeln('export DEBIAN_FRONTEND=noninteractive')
      ..writeln('apt-get update -qq 2>/dev/null || true')
      ..writeln(
        'apt-get install -y -qq locales 2>/dev/null || true',
      );
    for (final locale in config.locales) {
      buffer.writeln(
        "grep -qxF '$locale' /etc/locale.gen || echo '$locale' >> /etc/locale.gen",
      );
    }
    buffer
      ..writeln('locale-gen 2>/dev/null || true')
      ..writeln("echo 'LANG=${config.defaultLocale}' > /etc/locale.conf")
      ..writeln()
      ..writeln('# --- sysvinit-utils (provides the service command) ---')
      ..writeln(
        'apt-get install -y -qq sysvinit-utils 2>/dev/null || true',
      );
  }

  /// Installs a /usr/local/bin/systemctl shim that redirects common systemctl
  /// subcommands to SysV init / the service command.  systemd cannot run under
  /// proot (it needs PID 1 + cgroups); this shim makes the most common
  /// operations work without it.
  void _writeSystemctlShim(StringBuffer buffer) {
    buffer
      ..writeln()
      ..writeln('# --- systemctl proot shim ---')
      ..writeln('mkdir -p /usr/local/bin')
      ..writeln("cat > /usr/local/bin/systemctl <<'SYSTEMCTL_SHIM_EOF'")
      ..writeln('#!/bin/bash')
      ..writeln('# systemctl proot shim')
      ..writeln(
        '# Redirects common systemctl commands to SysV init / service.',
      )
      ..writeln(
        '# systemd requires PID 1 + kernel cgroups and cannot run in proot.',
      )
      ..writeln()
      ..writeln('_run_service() {')
      ..writeln('  local action="$1"')
      ..writeln('  local unit="${2%.service}"')
      ..writeln('  if command -v service >/dev/null 2>&1; then')
      ..writeln('    service "$unit" "$action"')
      ..writeln('  elif [ -x "/etc/init.d/$unit" ]; then')
      ..writeln('    /etc/init.d/"$unit" "$action"')
      ..writeln('  else')
      ..writeln(
        '    echo "systemctl: no init script found for \'$unit\'" >&2',
      )
      ..writeln('    return 1')
      ..writeln('  fi')
      ..writeln('}')
      ..writeln()
      ..writeln('cmd="${1:-}"')
      ..writeln('unit="${2:-}"')
      ..writeln()
      ..writeln('case "$cmd" in')
      ..writeln('  start|stop|restart|reload|status|try-restart)')
      ..writeln('    _run_service "$cmd" "$unit"')
      ..writeln('    ;;')
      ..writeln('  enable)')
      ..writeln(
        '    if command -v update-rc.d >/dev/null 2>&1; then',
      )
      ..writeln('      update-rc.d "${unit%.service}" defaults')
      ..writeln(
        '    elif command -v chkconfig >/dev/null 2>&1; then',
      )
      ..writeln('      chkconfig "${unit%.service}" on')
      ..writeln('    else')
      ..writeln(
        '      echo "systemctl enable: not available in this proot environment" >&2',
      )
      ..writeln('    fi')
      ..writeln('    ;;')
      ..writeln('  disable)')
      ..writeln(
        '    if command -v update-rc.d >/dev/null 2>&1; then',
      )
      ..writeln('      update-rc.d "${unit%.service}" remove')
      ..writeln(
        '    elif command -v chkconfig >/dev/null 2>&1; then',
      )
      ..writeln('      chkconfig "${unit%.service}" off')
      ..writeln('    else')
      ..writeln(
        '      echo "systemctl disable: not available in this proot environment" >&2',
      )
      ..writeln('    fi')
      ..writeln('    ;;')
      ..writeln('  daemon-reload)')
      ..writeln(
        '    echo "systemctl: daemon-reload is a no-op in proot (no systemd running)"',
      )
      ..writeln('    ;;')
      ..writeln('  is-active)')
      ..writeln(
        '    _run_service status "$unit" >/dev/null 2>&1 && echo "active" || echo "inactive"',
      )
      ..writeln('    ;;')
      ..writeln('  is-enabled)')
      ..writeln(
        '    ls /etc/rc3.d/S*"${unit%.service}" >/dev/null 2>&1 && echo "enabled" || echo "disabled"',
      )
      ..writeln('    ;;')
      ..writeln('  list-units|list-unit-files)')
      ..writeln(
        '    echo "UNIT                          LOAD   ACTIVE  SUB     DESCRIPTION"',
      )
      ..writeln('    for f in /etc/init.d/*; do')
      ..writeln('      [ -x "\$f" ] || continue')
      ..writeln('      name="\$(basename \$f).service"')
      ..writeln(
        '      printf "%-30s loaded active  running %s\\n" "\$name" "\$(basename \$f)"',
      )
      ..writeln('    done')
      ..writeln('    ;;')
      ..writeln('  --version)')
      ..writeln(
        '    echo "systemctl (proot-shim) -- redirects to SysV init"',
      )
      ..writeln('    ;;')
      ..writeln('  "")')
      ..writeln('    echo "Usage: systemctl COMMAND [UNIT]" >&2')
      ..writeln('    exit 1')
      ..writeln('    ;;')
      ..writeln('  *)')
      ..writeln(
        '    echo "systemctl: unknown command \'\$cmd\'" >&2',
      )
      ..writeln(
        '    echo "Available: start stop restart reload status enable disable daemon-reload is-active is-enabled list-units" >&2',
      )
      ..writeln('    exit 1')
      ..writeln('    ;;')
      ..writeln('esac')
      ..writeln('SYSTEMCTL_SHIM_EOF')
      ..writeln('chmod +x /usr/local/bin/systemctl');
  }

  void _writeFirstLoginWelcome(StringBuffer buffer, FirstBootConfig config) {
    final hint = config.packageManager == PackageManager.pacman
        ? 'Tip: run  pacman -Syu  to refresh before installing packages.'
        : 'Tip: run  apt-get update && apt-get upgrade  to refresh packages.';
    buffer
      ..writeln()
      ..writeln('# --- first-login welcome (shown once) ---')
      ..writeln('mkdir -p /etc/profile.d')
      ..writeln("cat > /etc/profile.d/conduit-welcome.sh <<'WELCOME'")
      ..writeln('if [ ! -f "\$HOME/.conduit-welcomed" ]; then')
      ..writeln('  echo "Linux environment running locally via Conduit."')
      ..writeln('  echo "$hint"')
      ..writeln('  echo')
      ..writeln('  touch "\$HOME/.conduit-welcomed" 2>/dev/null || true')
      ..writeln('fi')
      ..writeln('WELCOME');
  }

  void _writeDoneMarker(StringBuffer buffer, FirstBootConfig config) {
    buffer
      ..writeln()
      ..writeln('# --- mark complete ---')
      ..writeln('mkdir -p "\$(dirname "${config.doneMarkerPath}")"')
      ..writeln('touch "${config.doneMarkerPath}"');
  }
}
