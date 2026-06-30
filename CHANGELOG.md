VERSION="5.4"

# Changelog

## [v5.4] - 2026-06-30
### Added
- **3x-ui Integration**: Completely migrated the Xray backend to Sanaei's robust `3x-ui` panel for seamless proxy management.
- **REST API Wrapper**: Integrated `xui_api.py` into the BlueFalcon panel to communicate directly with 3x-ui's API in the background.
- **Advanced Dashboard**: Added a 1-click shortcut from the Xray tab directly into the native 3x-ui advanced interface.
### Removed
- Deprecated manual `reality.json` bash generation scripts to prevent file permission and syntax errors.


## [v5.3] - 2026-06-30
### Fixed
- **MISSING_PBK Permission Error**: Fixed an OS-level permission issue where the backend Python process (`app.py`) was denied read-access to the newly generated `/etc/xray/reality.json` file because it was created securely by root. The file is now safely `chmod 644` readable by the panel, guaranteeing the `pbk` variable populates perfectly.
- **Subscription QR Failure**: Fixed a typo in the JSON schema (`sub_url` vs `sub_link`) that caused the new "Sub Link" QR code tab to generate an empty/invalid QR block, which threw a "Failure" scan error on Android.

## [v5.2] - 2026-06-30
### Fixed
- **Xray REALITY strict key validation**: Implemented a resilient Python parsing block inside `core_setup.sh` to extract the `xray x25519` keys perfectly (guaranteeing a 43-character base64url string) irrespective of system architecture or OS variations.
- **VLESS URI Specification**: Added the strictly required `encryption=none` attribute to the VLESS TCP & xHTTP connection links to prevent v2rayN parser crashes.
- **QR Code Readability**: Added a margin "quiet zone" of `4` to the generated QR codes so smartphone cameras and v2rayNG can instantly detect the boundary.
- **Subscription Link QR**: Added a new "Sub Link" tab inside the QR code modal! You can now scan the subscription link directly to your phone.

## [v5.1] - 2026-06-30
### Fixed
- **Xray REALITY Key Generation**: Fixed a critical bug where `pbk` keys generated with ANSI color codes would break the Xray config and crash V2rayN/v2rayNG clients with "PublicKey property is invalid".
- **Hysteria 2 TLS Pinning**: Migrated away from `allowInsecure` to explicit `pinSHA256` certificate fingerprinting to resolve the "allowInsecure has been removed" Xray-core crash inside v2rayN and eliminate MITM warnings.

## [v5.0] - 2026-06-30
### Fixed
- **Wizard Xray Installer**: Fixed a bug where the installation stream would skip the Xray setup process during the initial wizard deployment.
- **Clipboard Fallback**: Implemented a robust fallback for copying QR links and Subscriptions in non-HTTPS environments where `navigator.clipboard` is restricted.
- **Hysteria 2 Client Compatibility**: Updated the Hysteria 2 connection URI to include `peer` and `allowInsecure=1` parameters to ensure compatibility with v2rayNG and other mobile clients.

## [v4.9] - 2026-06-30
### Added
- **Xray & Hysteria 2 Integration**: Added a new "Xray & Proxies" module with support for VLESS (TCP & xHTTP transport) + REALITY and Hysteria 2.
- **Dedicated User Management**: Separate user database for advanced proxies to keep standard VPN clients (OpenVPN/WireGuard) isolated from proxy clients.
- **QR Code & Subscription**: Added an automated subscription URI generation system (`/sub/xray/...`) that provisions all protocols with one click.
- **Modernized UI**: Refactored the WireGuard interface to use full-width stacked layouts, maintaining consistency with the OpenVPN tab.


## [v4.8] - 2026-06-30
### Fixed
- **IPv6 SLAAC Disablement Bug**: Fixed an extremely obscure Linux kernel quirk where enabling IPv6 forwarding (`net.ipv6.conf.all.forwarding=1`) automatically forces the server to drop all Router Advertisements (SLAAC) on reboot. This caused VPS providers with dynamic IPv6 allocations to permanently lose their native IPv6 route upon server restart. Hardcoded `accept_ra=2` in sysctl to force the kernel to maintain its native IPv6 configuration while simultaneously routing VPN traffic.

## [v4.7] - 2026-06-30
### Added
- **Dual-Stack Native IPv6 Tunneling**: Massively upgraded both OpenVPN and WireGuard routing engines to natively support IPv6 inside the VPN tunnels using Unique Local Address (ULA) subnets (`fd42::`). This permanently fixes IPv6 leaks on client devices and allows connected clients to utilize WARP's IPv6 routing seamlessly.
  - Added `ip6tables` NAT routing and `sysctl` IPv6 forwarding to all VPN installations.
  - Wireguard client generator now pushes `::/0` and statically assigns `fd42:42:42:43::/128` per user.
  - OpenVPN core setup now pushes `route-ipv6 2000::/3` and assigns a `server-ipv6 fd42:42:42:42::/112` topology.

## [v4.6] - 2026-06-30
### Fixed
- **True VPS IPv6 Detection**: Fixed an issue where the True VPS IPv6 address displayed as `N/A` on the WARP dashboard. The detection logic now strictly queries the `main` routing table rather than globally, preventing WARP's virtual interface from blinding the server to its native public interface.
- **Login Page UI Refinement**: Updated the login screen aesthetics for better clarity. Modified titles and properly contrasted the error banner using Tailwind classes (`bg-red-900/50 text-red-200`) so "Invalid Credentials" warnings are readable in dark mode. Also fixed a bug where the error banner displayed unconditionally on fresh page loads.
- **Bootstrapper Speed**: Added verbose logging to `install.sh` so the initial deployment no longer appears to hang while fetching core dependencies (`git`, `curl`, `wget`) on a fresh Ubuntu machine.

## [v4.5] - 2026-06-30
### Fixed
- **WARP Boot Sequence Bug**: Fixed a critical issue where WARP (`wg-quick@wgcf`) would initialize too early during the server boot sequence, causing DNS resolution and outgoing internet traffic to fail, effectively blackholing `bfu` and OpenVPN. Added an `@reboot` delayed start cron to ensure a clean initialization.
- **Preflight Internet Check**: Upgraded the `curl` internet connectivity check to bypass DNS resolution (`1.1.1.1`) to prevent false positives when WARP overrides `resolv.conf`.
- **Panel Internal Server Error**: Fixed a 500 crash in the Preferences tab caused by an unclosed database connection and an invalid `.get()` method call on a raw `sqlite3.Row` object.
- **Readonly Variable Crash**: Removed legacy `readonly APP_DIR` declarations across all module scripts that were crashing the `bfu` terminal command when sourced.

## [v4.4] - 2026-06-30
### Fixed
- **OpenVPN + WARP Routing Integrity**: Fixed a critical routing bug where OpenVPN failed to establish connections or drop packets when WARP was enabled.
  - Added `multihome` directive for UDP protocols so the OpenVPN server correctly replies from the original public interface instead of the WARP virtual interface.
  - Added `mssfix 1240` to clamp OpenVPN tunnel MTU below WARP's strict 1280 MTU, preventing MTU packet-loss blackholes.
  - Forced loose `rp_filter` (Reverse Path filtering) in sysctl to prevent the Linux kernel from dropping cross-routed packets natively.

## [v4.3] - 2026-06-29
### Changed
- **Unified Network Manager**: Completely overhauled the WARP installation script (`vpn-scripts/warp/action.sh`). Eradicated the official `cloudflare-warp` desktop daemon which was causing catastrophic routing conflicts and pulling in 662MB of GUI bloatware. Replaced it with pure `wgcf` + `wireguard-tools` policy routing.
- **Conflict Warning UI**: Added dynamic warning banners to the Web Panel dashboard. If WARP is running concurrently with OpenVPN or WireGuard, the dashboard actively informs the user that client outbound traffic is being bridged through Cloudflare.
- **Cross-Platform Compatibility**: Normalized all bash and python scripts to Linux (LF) line endings to fix `\r` crash bugs on fresh deployments. Added `.gitattributes` to enforce this behavior.
- **System Logs**: Fixed an issue where Ubuntu 24.04 nodes failed to load the authentication logs via `tail /var/log/auth.log`. Ported the logic to `journalctl -u ssh.service`.
- **Preflight Checks**: Replaced brittle ICMP `ping` checks with HTTPS `curl` checks to ensure compatibility with strict cloud provider firewalls (AWS, Oracle, etc).

## [v4.2] - 2026-06-29
### Fixed
- **WARP Client Revert**: Restored the exact `cloudflare-warp` installation behavior from `v4.0`. Removed the `--no-install-recommends` flag, as Cloudflare's proprietary client silently relies on some of those "recommended" dependencies (like `systemd-resolved` or `glib` networking tools) to establish its tunnel correctly.

## [v4.1] - 2026-06-29
### Fixed
- **WARP Bloatware Installation**: Added `--no-install-recommends` to the Cloudflare WARP client installation script. This prevents the server from unnecessarily downloading and installing over 600MB of useless graphical desktop environments and GUI libraries on a headless VPS.

## [v4.0] - 2026-06-29
### Changed
- **Terminal Shortcut**: Renamed the global terminal shortcut back to `bfu` (BlueFalcon Ultimate) per user request.

## [v3.9.1] - 2026-06-29
### Fixed
- **Panel Access Blocked via UFW**: Fixed an issue where installing OpenVPN or WARP would reload UFW and accidentally block the Web Panel port (2020).
- **Wizard Redirect Loop**: Fixed a bug where restarting the server with only one protocol installed would mistakenly trigger the Setup Wizard due to a flawed database check.

## [v3.9] - 2026-06-29
### Fixed
- **Server Name Display**: Fixed bug where the panel would always display "openvpn" as the server name. Added a dedicated `display_name` column to allow custom node names while keeping protocol identifiers intact.
- **Install State Persistence**: Fixed bug where running an install from the dashboard tabs wouldn't properly update the `is_installed` status upon completion, leaving the UI stuck in the "Not Installed" state.

## [v3.8] - 2026-06-28
### Fixed
- **WireGuard Panel (Critical)**: Fixed `Internal Server Error` caused by calling `get_db_connection()` which doesn't exist — all calls now correctly use `get_db()`.
- **OpenVPN Install (Critical)**: Same undefined function fix for the `/api/openvpn_stream` and `/api/add_wg_user` routes.
- **OpenVPN & WireGuard "Not Installed" UI**: Completely redesigned to match the WARP page — full-width card with persistent, large terminal always visible on screen. Terminal shows live log as soon as you click Install.
- **Auto-resume polling**: If you navigate away and come back while an install is running, the terminal will automatically resume showing the live log.

## [v3.7] - 2026-06-28
### Added
- **Wizard Redesign**: The deployment wizard has been completely redesigned. It now features sleek collapsible boxes for OpenVPN, WireGuard, and WARP, with modern toggle switches (defaulting to OFF).
- **Modular OpenVPN**: OpenVPN is no longer forced to install during the initial setup wizard. It can be skipped and installed later directly from the Web Panel, matching the behavior of WireGuard and WARP.

## [v3.6] - 2026-06-28
### Added
- **WireGuard Protocol**: Added full support for WireGuard.
  - **CLI Menu**: Manage WireGuard installation, port selection, and users via `bfp`.
  - **Web Panel**: A new dedicated WireGuard tab featuring installation streams, custom port selection, user management, `.conf` downloads, and live QR code generation for mobile devices.

## [v3.5] - 2026-06-28
### Fixed
- **System Packages**: Docker Engine and Docker Compose are now correctly installed via the "Install Missing" button. Previously, it skipped the Docker repository setup.
- **Terminal Formatting**: The system update and package installation terminal logs now perfectly mirror the CLI menu's exact text layout and hide raw `apt` output during package installation.

## [v3.4] - 2026-06-28
### Added
- **ANSI Color Rendering**: All terminal outputs (System Tools, WARP, Backup) now render colored output identical to the CLI menu — bold blue headers, green checkmarks, red errors.
- **Auto-scroll Toggle**: Every terminal in the panel now has a green toggle switch. When ON, the terminal auto-scrolls to the newest line. When OFF, you can freely scroll to read previous output without being interrupted.
- **Styled Scrollbar**: All terminals now have a thin, dark-styled scrollbar that is always visible.
- **`install_packages` action**: System Packages tab now installs all missing packages via the live terminal.

## [v3.3] - 2026-06-28
### Changed
- **System Tools**: Redesigned page with tabs (Update System, System Packages, SSH Settings). Each tab has its own context and the permanent terminal is present in applicable tabs.
- **Backup/Restore**: Moved from System Tools to a dedicated tab inside Preferences.
- **SSH Settings**: Added toggle switches for Password Auth and Pubkey Auth directly from the web panel.
- **Terminal Command**: Renamed the CLI shortcut from `bf-ui` to `bfp` for faster access.

## [v3.2] - 2026-06-28
### Added
- **System Tools (Phase 1)**: Migrated 'Essentials' and 'Backup/Restore' from the CLI to a new dedicated Web Panel tab.
- **Backup Vault**: Users can now create, restore, download, and delete full system backups directly from the web interface.
- **Permanent System Terminal**: Added a permanently visible background terminal to execute system updates and restorations in real-time.

## [v3.1] - 2026-06-28
### Added
- **WARP Persistent Terminal**: The WARP installation process now runs in a background thread and logs to `/tmp/warp_install.log`. The frontend uses a collapsible terminal that resumes polling even after a page reload.
### Changed
- **OpenVPN UI Tweaks**: Removed literal placeholders from the Add User form, shortened 'Max Users', and simplified table headers.
- **WARP IP Logic**: Applied Single Green Circle rule: True Server IP gets green when OFF, WARP IP gets green when ON. Inactive WARP IP displays as `Offline`.

## [v3.0] - 2026-06-27
### Fixed
- **OpenVPN Layout Typo**: Corrected 'Sim...Users:' summary text to display 'Simultaneous Users:'.
- **WARP UI States**: Fixed the active/inactive circle colors and conditional rendering. True Server IPs now properly always display as active (green). Uninstalled WARP now displays a clean placeholder instead of unmasked IPs.
- **Engine Controls Theme**: Manually mapped the Start/Stop buttons to perfectly match the requested light-pastel mockup styling, overriding global dark mode.

## [v2.9] - 2026-06-27
### Fixed
- **Version Display Bug**: Fixed path resolution in `app.py` so the About tab dynamically reads the current version.
### Changed
- **WARP UI**: Realigned True Server IP and WARP IP with perfectly centered text and right-aligned status circles. Removed top color bars.
- **OpenVPN UI**: Redesigned structure based on user mockup (Settings banner, inline "Add User" horizontal form, and dark-theme clients table).

## [v2.8] - 2026-06-26
### Added
- `.agents` directory to `.gitignore` to prevent leaking local AI context.

## [v2.7] - 2026-06-26
### Added
- **UI Overhaul**: Complete UI overhaul for WARP, OpenVPN, and Preferences tabs.
- **Server Configuration**: Added Server Name configuration in Preferences.

## [v2.6] - 2026-06-26
### Added
- **Unified Preferences Page**: Combined Settings and Logs into a unified 'Preferences' page with an 'About' tab.
- **Centralized Versioning**: Project version is now centrally defined in `CHANGELOG.md` and read by all Bash and Python scripts.
- **`.gitignore`**: Added strict ignoring for `panel.db`, log files, and Python cache.
- **CLI Logging Enhancement**: All main CLI scripts now output the Toolkit version dynamically on launch.

### Changed
- **Web Panel Sidebar**: Removed categorized groupings and renamed the header to a stylized 'BF Panel'.
- **Panel CLI Menu**: Removed redundant 'View Installation Logs' option to centralize all logging to the unified Log Center.

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
