# Changelog

## [v2.5] - 2026-06-25
### Added
- **Hybrid Log Center**: Introduced a comprehensive centralized logging system supporting 9 different log feeds.
- **Unified Master Stream**: Added a new chronological interleaved log feed covering Web Panel, OpenVPN, and WARP outputs.
- **Backup & Restore Module**: Integrated a new module for archiving and restoring VPN configs and Web Panel database.

### Changed
- **CLI Sub-menus**: Removed redundant log viewing options from OpenVPN, WARP, and Web Panel modules, deferring logging to the new Log Center.
- **CLI Main Menu**: Reordered items logically according to importance (Web Panel, OpenVPN, WARP, Essentials, Backup/Restore, Logs).
- **Web Panel Dashboard**: Integrated Chart.js for real-time network traffic visualization.
- **Web Panel Sidebar**: Grouped items logically under 'Overview', 'Network Services', and 'Administration'.
- **Web Panel OpenVPN UI**: Relocated the user provisioning form into a sleek Floating Action Button (FAB) and modal.
- **Web Panel Logs UI**: Replaced horizontal tabs with a modern dropdown selector.

### Security
- **Subprocess Hardening**: Migrated user script executions in `app.py` from `os.system` to `subprocess.run` to mitigate shell injection.
- **Input Sanitization**: Implemented strict stripping of newlines and quotes for DNS input fields to prevent config corruption.
- **Exception Handling**: Improved `get_traffic()` to gracefully catch `FileNotFoundError` and `PermissionError`.
