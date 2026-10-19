# Changelog

All notable changes to Atlas Scripts are documented here. Release entries are
based on the versioned commits in the repository history; merge commits and
intermediate planning commits are omitted.

## 1.78 - 2026-10-19

### Added

- Added `install.sh --no-update` to install selections without upgrading the
  host system. `--update` remains available as an explicit form of the default
  behavior.
- Added CI checks for README-local references and workflow YAML syntax.
- Added `jq` and `yamllint` to the CI validation toolchain.

### Changed

- CI now runs on pushes to all branches and cancels superseded runs for the
  same ref.
- Non-interactive `setup.sh` runs no longer change the login shell unless
  `--yes` is supplied explicitly.
- Documented script selection options and configuration-format enforcement
  recommendations.

## 1.77-1 - 2026-10-19

### Changed

- Refined the Neofetch fallback configuration and its presentation.

## 1.77 - 2026-10-19

### Added

- Added Nano syntax highlighting for C and Python.

### Fixed

- Corrected the Fish greeting.
- Fixed CI and improved shell, C, Python, and shell-syntax validation.

## 1.76 - 2026-09-20

### Added

- Added a Neofetch fallback when Fastfetch is unavailable.
- Expanded CI coverage for the fallback installation path and configuration
  smoke tests.

### Changed

- Updated the Fish greeting and fallback configuration handling.

## 1.75 - 2026-09-18

### Changed

- Refactored GitHub Actions configuration and expanded CI validation.

## 1.74 - 2026-09-18

### Added

- Added automatic Fastfetch installation from the upstream static build when
  the distribution does not provide a package.
- Added fallback and package-resolution helpers shared by the installation
  scripts.

### Changed

- Updated the Fish greeting and documentation.

## 1.73 - 2026-09-17

### Changed

- Revamped the Fastfetch configuration with the boxed system and hardware
  layout.
- Improved the Nano configuration.

## 1.72 - 2026-09-17

### Added

- Added Nano syntax highlighting for CSS, JSON, Markdown, and YAML.

## 1.71 - 2026-09-16

### Added

- Added the Fish prompt and a progress bar for gum installation.

### Fixed

- Fixed gum installation and Fish prompt behavior.

## 1.70 - 2026-09-15

### Changed

- Refactored the setup and installation scripts for clearer selection,
  improved usability, and stronger error handling.
- Consolidated shared script helpers in `lib/common.sh`.
- Added or expanded CI, licensing, and configuration documentation.

## 1.69 - 2026-09-15

### Added

- Added `restore.sh` for restoring the newest backups made by `setup.sh`.
- Added setup link mode, dry-run support, idempotent deployments, and
  timestamped backups.
- Added the initial CI workflow, license, and `VERSION` file.

### Fixed

- Hardened shared helpers, package installation, and NVIDIA installation
  behavior.
- Corrected setup behavior and handling of empty Git configuration input.

## 1.68 - 2026-09-06

### Changed

- Renamed the tracked dotfiles directory to `config`.
- Updated the NVIDIA driver version used by `nvidia.sh`.

## 1.67 - 2026-08-05

### Changed

- Renamed `nvidia595.sh` to `nvidia.sh`.
- Updated the NVIDIA driver release used by the installer.

## 1.66 - 2026-08-05

### Changed

- Updated the Fastfetch configuration and README.

## 1.65 - 2026-07-20

### Changed

- Updated Fastfetch colors.

## 1.64 - 2026-07-01

### Changed

- Updated the Fish greeting.

## 1.63 - 2026-07-01

### Fixed

- Fixed Fastfetch colors and greeting behavior.

## 1.62 - 2026-07-01

### Fixed

- Fixed the hostname shown by the Fish greeting.

### Changed

- Updated Fastfetch colors.

## 1.61 - 2026-07-01

### Changed

- Made minor improvements to the Fish greeting.

## 1.6 - 2026-07-01

### Changed

- Updated the README, setup scripts, installation flow, and configurations as
  part of the 1.6 release.

## 1.4 - 2026-06-30

### Changed

- Updated setup scripts and added Fastfetch configuration support.

## 1.3 - 2026-06-22

### Changed

- Refactored the distribution-specific installers into a unified installation
  flow.

### Fixed

- Fixed individual package installation errors and Fish function handling.

## 1.0 - 2026-06-10

### Added

- Introduced the Atlas Scripts bootstrap project.
- Added setup and installation scripts for a fresh Linux system.
- Added Fish configuration and system-information configuration.
- Added the NVIDIA driver and Container Toolkit installer.
- Added shared shell helpers and distro-aware package handling.
