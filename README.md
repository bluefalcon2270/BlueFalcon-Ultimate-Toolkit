<div align="center">

# 🧰 BlueFalcon Ultimate Toolkit

**The fast, safe, and absolute best way to prepare, route, and manage a fresh Linux server.**

![Linux](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu-FCC624?style=for-the-badge&logo=linux&logoColor=black)
[![Language](https://img.shields.io/badge/Written%20in-Shell/Python-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@BlueFalcon2270)

<br />
</div>

An all-in-one, automated shell script to completely set up a fresh Linux server. It handles everything from initial security and utility installations (including Docker), to advanced Cloudflare WARP routing, and finally, a universal web dashboard for one-click VPN management.
<br><br>

## ⚡ Quick Run
Copy and run this single command with root privileges on your fresh VPS:

```bash
wget -O setup.sh https://raw.githubusercontent.com/bluefalcon2270/bluefalcon-ultimate-toolkit/main/setup.sh && sudo bash setup.sh
```

<br>

## 🌟 Features
By running this script, you access a unified, master terminal menu with the following capabilities:

### 1️⃣ Essential Tools
* **Update System:** Run standard package updates non-interactively.
* **System Packages:** Installs a critical checklist of packages (including `nano`, `curl`, `git`, `htop`, `ufw`, `iptables`, and the complete `docker-ce` engine & compose plugins).
* **SSH Settings:** Change your SSH port, root password, and securely toggle password vs. key logins directly from a status dashboard.

### 2️⃣ OpenVPN & Web Panel
* **Live Dashboards:** Monitor your server's live health (CPU, RAM, Disk, Network) with real-time graphs.
* **Protocol Independent Setup:** The panel sits in the root directory, ensuring maximum compatibility. Currently configured for automated OpenVPN deployment, traffic tracking, and automated profile generation.
* **One-Click Controls:** Pause/resume users, set expiry dates, and download mobile/desktop profiles instantly.

### 3️⃣ Cloudflare WARP
* **Dual-Stack Routing:** Hide your server's true IP and bypass restrictions by routing IPv4 and/or IPv6 traffic through Cloudflare's WireGuard network (`wgcf`).
* **WARP+ Support:** Upgrade your connection instantly using a premium license key.
* **Live Dashboard:** Displays active connection statuses, server IPs, and WARP masking IPs all in real time.

<br><br>

## ✅ Supported Systems
| Distribution | Compatibility |
| :--- | :---: |
| **Ubuntu** (22.04, 24.04) | ✅ |
| **Debian** (11, 12, 13) | ✅ |

<br><br>

---
**Watch the Tutorial:** I use this exact toolkit in my YouTube tutorials to ensure viewers have a standardized, error-free environment before we dive into advanced server deployments.