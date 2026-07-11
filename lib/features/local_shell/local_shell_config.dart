import 'package:conduit/features/local_shell/domain/rootfs_manifest.dart';

const _base = 'https://github.com/termux/proot-distro/releases/download';

/// All distros available in the local shell picker, in display order.
final allLocalDistros = [archLinuxDistro, ubuntu2404Distro, debian12Distro];

/// Arch Linux ARM — rolling release, pacman, from Termux proot-distro v4.22.1.
final archLinuxDistro = RootfsManifest(
  distroId: 'archlinux',
  displayName: 'Arch Linux ARM',
  packageManager: PackageManager.pacman,
  version: 'archlinux-aarch64-pd-v4.22.1',
  archiveUrl: Uri.parse(
    '$_base/v4.22.1/archlinux-aarch64-pd-v4.22.1.tar.xz',
  ),
  sha256: 'b7e4cfb1414a281f90bfd39a503f72f38e03c31b356927972f797988fb48b5b1',
  downloadSizeBytes: 149200240,
  pacmanMirror: r'http://mirror.archlinuxarm.org/$arch/$repo',
);

/// Ubuntu 24.04 LTS (Noble Numbat) — apt, from Termux proot-distro v4.18.0.
final ubuntu2404Distro = RootfsManifest(
  distroId: 'ubuntu',
  displayName: 'Ubuntu 24.04',
  packageManager: PackageManager.apt,
  version: 'ubuntu-noble-aarch64-pd-v4.18.0',
  archiveUrl: Uri.parse(
    '$_base/v4.18.0/ubuntu-noble-aarch64-pd-v4.18.0.tar.xz',
  ),
  sha256: '3a841a794ae5999b33e33b329582ed0379d4f54ca62c6ce5a8eb9cff5ef8900b',
  downloadSizeBytes: 64133552,
);

/// Debian 12 (Bookworm) — apt, from Termux proot-distro v4.17.3.
final debian12Distro = RootfsManifest(
  distroId: 'debian',
  displayName: 'Debian 12',
  packageManager: PackageManager.apt,
  version: 'debian-bookworm-aarch64-pd-v4.17.3',
  archiveUrl: Uri.parse(
    '$_base/v4.17.3/debian-bookworm-aarch64-pd-v4.17.3.tar.xz',
  ),
  sha256: '91acaa786b8e2fbba56a9fd0f8a1188cee482b5c7baeed707b29ddaa9a294daa',
  downloadSizeBytes: 42912980,
);
