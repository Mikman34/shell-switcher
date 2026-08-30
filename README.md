Noctalia ↔ DMS Shell Toggle (Niri)

A one-command way to switch between Noctalia and DankMaterialShell (DMS) on niri, without logging out or hand-editing config files.

The problem

Both Noctalia and DMS are full Quickshell-based shells for niri — bar, launcher, notifications, power menu, etc. Running both at once means duplicate bars, duplicate notification daemons, and keybind collisions, since niri's config is static and whichever shell's keybinds are active in config.kdl will "win" over the other, even if the other shell isn't running.

Specific issues hit along the way:

Niri's config.kdl had Noctalia's keybinds (Alt+Space, Alt+Escape, Mod+L, Mod+Shift+B) hardcoded and not commented out. Since niri reads keybinds from its static config file, these bindings claimed those keys regardless of which shell was actually running — so DMS's own shortcut settings for the same keys (e.g. Alt+Space → Spotlight launcher) were silently dead.
DMS writes its own keybinds to ~/.config/niri/dms/binds.kdl, but that file only takes effect if it's included from config.kdl. The include line was present but commented out, so DMS's keybinds were never actually loaded into niri.
DMS is normally started via dms.service (systemd), but that unit depends on graphical-session.target, which only activates if niri itself is launched as a systemd service. Since niri here is started outside of systemd (e.g. from a TTY/display manager), that target never activates and dms.service fails with a "dependency" error. Solution: skip systemd for DMS entirely and start/stop it as a plain background process, same as Noctalia.
The fix: shell-toggle

A bash script (~/.local/bin/shell-toggle) that, on each run:

Detects which shell is currently running (pgrep -x noctalia).
Kills the active one.
Comments/uncomments the relevant lines in ~/.config/niri/config.kdl:
The spawn-at-startup "noctalia" line, so the right shell autostarts on next login too.
Noctalia's hardcoded keybind lines, freeing those keys for DMS.
The include "dms/binds.kdl" line, so DMS's keybinds load only while DMS is active.
Reloads niri's config live (niri msg action load-config-file) — no logout needed.
Starts the other shell as a detached background process (setsid ... & disown).

Setp:
Save the script to ~/.local/bin/shell-toggle and make it executable: chmod +x ~/.local/bin/shell-toggle.
Make sure dms.service is disabled so it doesn't fight with the script: systemctl --user disable dms.
In ~/.config/niri/config.kdl, keep the include for DMS's keybinds present but commented out by default: //include "dms/binds.kdl" (the script toggles it).
Optionally bind it to a key in niri:
Mod+Shift+S { spawn "shell-toggle"; }

Then reload with niri msg action load-config-file.

Usage
shell-toggle in the terminal.

Run it any time to flip between Noctalia and DMS. Whichever shell is active also gets its keybinds live in niri; the other shell's binds are commented out until you switch back.

Notes / gotchas
If you're on fish shell, heredocs (<< 'EOF') aren't supported the same way as bash — drop into bash first when editing the script.
DMS's power menu is bound via IPC: dms ipc call powermenu toggle. Bind it either by editing dms/binds.kdl directly, or through DMS's own in-app shortcut editor (Settings → Keyboard Shortcuts → +), which writes to the same file.
Full DMS IPC reference: DankMaterialShell/docs/IPC.m
