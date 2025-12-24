# SETUP.md - Hardware Optimization (HP Gaming Pavilion Hybrid)
This documentation describes the necessary steps to operate a hybrid graphics system (Intel + NVIDIA) stably and performantly under Linux (XFCE/LightDM).

# 1. Graphics Driver & Power Management
To fully power off the NVIDIA GPU when idle (Power-Off) and to preserve the video memory during standby, create the file /etc/modprobe.d/nvidia-power-management.conf:

```text
# Enables video memory preservation during suspend
options nvidia "NVreg_PreserveVideoMemoryAllocations=1"
# Enables Dynamic Power Management (D3 status for Turing+ cards)
options nvidia "NVreg_DynamicPowerManagement=0x02"
```

Enable required services:
```bash
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
```
# 2. Kernel Parameters (GRUB)
To prevent black screens after standby and to fix panel flickering (common on HP laptops), add the following parameters to /etc/default/grub:

nvidia-drm.modeset=1 : Enables framebuffer synchronization.

i915.enable_psr=0 : Disables Panel Self Refresh (fixes black screen bugs on HP hardware).

mem_sleep_default=deep : Forces the system into deep sleep (S3) instead of s2idle, which prevents wake-up failures on NVIDIA hardware.

Configuration: GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvidia-drm.modeset=1 i915.enable_psr=0 mem_sleep_default=deep"

Afterwards, run sudo update-grub.

# 3. Display Manager (LightDM)
To ensure the graphical interface only starts once the drivers are fully initialized, the following line was activated in /etc/lightdm/lightdm.conf:

```Ini,toml
[Seat:*]
logind-check-graphical=true
display-setup-script=/etc/lightdm/display_setup.sh
```
The script /etc/lightdm/display_setup.sh ensures correct xrandr initialization:

```bash
#!/bin/sh
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
```

# 4. Workload Offloading (NVIDIA-Run)
To launch computationally intensive applications (GKE-related simulations, etc.) on the dedicated GPU, a wrapper script was created at /usr/local/bin/nvrun:

```bash
#!/bin/bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia "$@"
```
# 5. Local Environment: Xubuntu (XFCE) Fix
Issue: Desktop content "shifts" or follows the mouse cursor (Viewport Panning).

Cause: Accidental trigger of Alt + Mouse Scroll (XFCE Zoom).

Fix: Used Alt + Scroll Down to reset. Permanent fix: Disabled Zoom in Settings -> Window Manager -> Keyboard.

# Project Significance:
This configuration ensures that the local development instance of the Hybrid Autonomy Project:

Prevents overheating through optimized GPU idling.

Remains stable and ready for use immediately after standby cycles.

Provides maximum computing power with minimal latency for autonomous workloads.