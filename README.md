Noctalia ↔ DMS Shell Toggle (Niri)

Shell: Bash Compositor: niri Works on: Arch Works on: NixOS

A one-command way to switch between Noctalia and DankMaterialShell (DMS) on niri, without logging out or hand-editing config files. Includes an fzf-based picker so you can see which shell is active and select the other one explicitly.

Contents
The problem
The fix: shell-toggle
NixOS compatibility
Setup
Usage
Notes / gotchas
The problem

Both Noctalia and DMS are full Quickshell-based shells for niri — bar, launcher, notifications, power menu, etc. Running both at once means duplicate bars, duplicate notification daemons, and keybind collisions, since niri's config is static and whichever shell's keybinds are active in config.kdl will "win" over the other, even if the other shell isn't running.

Specific issues hit along the way:

Niri's config.kdl had Noctalia's keybinds (Alt+Space, Alt+Escape, Mod+L, Mod+Shift+B) hardcoded and not commented out. Since niri reads keybinds from its static config file, these bindings claimed those keys regardless of which shell was actually running — so DMS's own shortcut settings for the same keys (e.g. Alt+Space → Spotlight launcher) were silently dead.
DMS writes its own keybinds to ~/.config/niri/dms/binds.kdl, but that file only takes effect if it's included from config.kdl. The include line was present but commented out, so DMS's keybinds were never actually loaded into niri.
DMS is normally started via dms.service (systemd), but that unit depends on graphical-session.target, which only activates if niri itself is launched as a systemd service. Since niri here is started outside of systemd (e.g. from a TTY/display manager), that target never activates and dms.service fails with a "dependency" error. Solution: skip systemd for DMS entirely and start/stop it as a plain background process, same as Noctalia.
The fix: shell-toggle

A bash script (~/.local/bin/shell-toggle) that:

Detects which shell is currently running (pgrep -x noctalia).
Shows an fzf picker listing both shells, with the currently active one shown in the prompt.
If you pick the shell that's already running, it does nothing. Otherwise it:
Kills the active shell.
Comments/uncomments the relevant lines in ~/.config/niri/config.kdl:
The spawn-at-startup "noctalia" line, so the right shell autostarts on next login too.
Noctalia's hardcoded keybind lines, freeing those keys for DMS.
The include "dms/binds.kdl" line, so DMS's keybinds load only while DMS is active.
Reloads niri's config live (niri msg action load-config-file) — no logout needed.
Starts the newly selected shell as a detached background process (setsid ... & disown).

Requires fzf to be installed.

<details> <summary><code>~/.local/bin/shell-toggle</code> (click to expand)</summary>
</details>
NixOS compatibility

The script works unchanged on NixOS as long as config.kdl is a plain writable file (i.e. you're not managing it declaratively through home-manager). Two gotchas to watch for:

Shebang: NixOS has no /bin/bash — everything lives under /nix/store and /run/current-system/sw/bin/. Use the portable shebang #!/usr/bin/env bash instead of #!/bin/bash, or the script fails to launch with "No such file or directory" / "not an executable command".
Process detection: NixOS wraps binaries in /nix/store, which truncates the kernel-level process name (/proc/PID/comm, what pgrep -x matches against) to 15 characters — so noctalia becomes .noctalia-wrapp. This makes pgrep -x noctalia silently fail to detect a running Noctalia even though it's active. Use pgrep -f "noctalia" instead, which matches against the full command line and works identically on Arch and NixOS.

If you do use home-manager and config.kdl is Nix-store-managed (read-only), the sed -i calls will fail outright — that setup needs a different approach (a mutable symlink file that config.kdl includes, toggled by the script instead of editing the store-managed file directly).

Required packages: fzf, libnotify (notify-send), procps (pgrep/pkill) — install via environment.systemPackages or nix-env if not already present.

Setup
Save the script to ~/.local/bin/shell-toggle and make it executable: chmod +x ~/.local/bin/shell-toggle.
Make sure dms.service is disabled so it doesn't fight with the script: systemctl --user disable dms.
In ~/.config/niri/config.kdl, keep the include for DMS's keybinds present but commented out by default: //include "dms/binds.kdl" (the script toggles it).
Optionally bind it to a key in niri:
Mod+Shift+S { spawn "shell-toggle"; }

Then reload with niri msg action load-config-file.

Usage
shell-toggle

This opens an fzf picker showing "Noctalia" and "DMS", with the currently active one shown in the prompt text. Select the shell you want — picking the one already running does nothing; picking the other one switches. Press Esc to cancel without changes.

Since fzf needs a terminal, if you bind this to a niri key, launch it inside a terminal rather than headless:

Mod+Shift+S { spawn "kitty" "-e" "shell-toggle"; }

Then reload with niri msg action load-config-file.

Notes / gotchas
If you're on fish shell, heredocs (<< 'EOF') aren't supported the same way as bash — drop into bash first when editing the script.
DMS's power menu is bound via IPC: dms ipc call powermenu toggle. Bind it either by editing dms/binds.kdl directly, or through DMS's own in-app shortcut editor (Settings → Keyboard Shortcuts → +), which writes to the same file.
Full DMS IPC reference: DankMaterialShell/docs/IPC.md
