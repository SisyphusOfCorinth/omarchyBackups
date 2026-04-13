# How Omarchy Orchestrates the Windows VM

Omarchy provides a seamless Windows 11 VM experience by combining Docker-based QEMU/KVM virtualization with RDP display and Hyprland desktop integration. The result is a Windows environment that launches from the app menu and feels like a native fullscreen application.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Hyprland (Super+Space launcher)                    │
│    └── windows-vm.desktop                           │
│          └── omarchy-windows-vm launch              │
│                ├── docker-compose up (QEMU/KVM)     │
│                └── xfreerdp3 fullscreen (RDP:3389)  │
│                      ├── clipboard sharing          │
│                      ├── audio + mic passthrough     │
│                      └── dynamic resolution         │
└─────────────────────────────────────────────────────┘
```

## Components

### 1. Main Script: `~/.local/share/omarchy/bin/omarchy-windows-vm`

The central orchestration script (~450 lines of bash) providing five commands:

| Command | Description |
|---------|-------------|
| `install` | Interactive wizard to configure and start the VM for the first time |
| `launch [--keep-alive\|-k]` | Boot the VM (if needed) and connect via RDP |
| `stop` | Gracefully shut down the VM |
| `remove` | Delete the VM, its data, and desktop entry |
| `status` | Show current VM state and connection info |

### 2. Docker Compose Config: `~/.config/windows/docker-compose.yml`

Generated during installation. Defines the VM container:

```yaml
services:
  windows:
    image: dockurr/windows
    container_name: omarchy-windows
    environment:
      VERSION: "11"
      RAM_SIZE: "8G"        # User-selected
      CPU_CORES: "4"        # User-selected
      DISK_SIZE: "64G"      # User-selected
      USERNAME: "..."       # User-selected
      PASSWORD: "..."       # User-selected
      TZ: "America/Chicago" # Auto-detected from host
      ARGUMENTS: "-rtc base=localtime,clock=host,driftfix=slew"
    devices:
      - /dev/kvm            # KVM hardware acceleration
      - /dev/net/tun        # NAT networking
    cap_add:
      - NET_ADMIN
    ports:
      - 127.0.0.1:8006:8006    # noVNC web UI (installation monitoring)
      - 127.0.0.1:3389:3389/tcp # RDP
      - 127.0.0.1:3389:3389/udp
    volumes:
      - ~/.windows:/storage     # VM disk image and UEFI vars
      - ~/Windows:/shared       # Host-guest file sharing
    restart: unless-stopped
    stop_grace_period: 2m
```

**Key design choice**: The `dockurr/windows` Docker image handles everything — downloading the Windows ISO, installing Windows, injecting drivers, and exposing RDP. The user never touches QEMU directly.

### 3. Desktop Entry: `~/.local/share/applications/windows-vm.desktop`

```ini
[Desktop Entry]
Name=Windows
Comment=Start Windows VM via Docker and connect with RDP
Exec=uwsm app -- omarchy-windows-vm launch
Icon=~/.local/share/applications/icons/windows.png
Terminal=false
Type=Application
Categories=System;Virtualization;
```

The `uwsm app --` wrapper ensures proper Wayland session management under Hyprland. This makes "Windows" appear as a launchable app via **Super + Space**.

### 4. Hyprland Window Rules: `~/.local/share/omarchy/default/hypr/apps/qemu.conf`

```
windowrule = tag -default-opacity, match:class qemu
windowrule = opacity 1 1, match:class qemu
```

This removes the default transparency that Omarchy applies to all windows, giving QEMU/RDP windows full opacity so the VM looks crisp.

The parent config (`~/.local/share/omarchy/default/hypr/windows.conf`) also applies `suppress_event maximize` globally, which prevents the VM window from fighting with Hyprland's tiling.

### 5. Storage Layout

| Path | Purpose |
|------|---------|
| `~/.windows/` | VM disk image (`data.img`), UEFI vars, boot config |
| `~/Windows/` | Shared folder — mounted as `/shared` inside the VM |
| `~/.config/windows/docker-compose.yml` | Docker compose configuration |

## Installation Flow

```
omarchy-windows-vm install
        │
        ▼
  Check prerequisites (KVM, disk space)
        │
        ▼
  Install packages: freerdp, openbsd-netcat, gum
        │
        ▼
  Interactive prompts (gum):
    - RAM allocation (2-64GB in 2GB increments)
    - CPU cores (1 to system max)
    - Disk size (32-512GB based on available space)
    - Username / Password
        │
        ▼
  Display configuration summary, confirm
        │
        ▼
  Generate docker-compose.yml
  Create ~/Windows/ shared folder
  Create .desktop file + icon
        │
        ▼
  docker-compose up -d
        │
        ▼
  Open browser to http://127.0.0.1:8006 (noVNC)
  User monitors Windows installation progress
```

The `dockurr/windows` image automatically downloads the Windows 11 ISO, installs it, and configures RDP. This takes ~15 minutes on first boot. Subsequent boots take 15-30 seconds.

## Launch Flow

```
omarchy-windows-vm launch
        │
        ▼
  Check compose file exists
  Extract credentials from docker-compose.yml
        │
        ▼
  Is container running?
    NO  → docker-compose up -d
          Wait for "windows started successfully" in logs (up to 2 min)
          Send desktop notification while waiting
    YES → Continue
        │
        ▼
  Detect Hyprland monitor scale (hyprctl monitors -j)
  Calculate RDP scale factor
        │
        ▼
  Launch xfreerdp3:
    xfreerdp3 /u:USER /p:PASS /v:127.0.0.1:3389
      -grab-keyboard          # VM captures keyboard input
      /sound /microphone      # Audio passthrough
      /clipboard              # Clipboard sharing
      /cert:ignore            # Skip TLS cert validation (localhost)
      /title:"Windows VM - Omarchy"
      /dynamic-resolution     # Adapts to monitor size
      /gfx:AVC444             # High-quality graphics codec
      /floatbar:sticky:off,default:visible,show:fullscreen
      /scale:100
        │
        ▼
  (User works in fullscreen Windows)
        │
        ▼
  RDP session closed
    --keep-alive flag? → VM keeps running
    No flag?           → docker-compose down (auto-stop)
```

## What Makes It Seamless

1. **One-click launch**: Super+Space → type "Windows" → Enter. No terminal needed.
2. **Fullscreen RDP**: The xfreerdp3 client fills the screen with dynamic resolution — it looks like you booted into Windows.
3. **Keyboard grab**: All keypresses (including Super, Alt+Tab, etc.) go to the VM when focused.
4. **Clipboard + audio**: Copy/paste and sound work between host and guest.
5. **Auto lifecycle**: VM starts when you launch, stops when you disconnect. No orphaned containers.
6. **Shared folder**: Drop files in `~/Windows/` on the host, pick them up at the mapped drive in the guest.
7. **Full opacity**: Hyprland window rules ensure the VM window isn't transparent like other apps.

## Dependencies

- **Docker** (with `docker-compose`)
- **KVM** (`/dev/kvm` — requires Intel VT-x or AMD SVM in BIOS)
- **freerdp** (provides `xfreerdp3`)
- **openbsd-netcat** (port checking)
- **gum** (interactive CLI prompts)
- **dockurr/windows** Docker image (pulled automatically)
