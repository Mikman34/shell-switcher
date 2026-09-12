# Noctalia ↔ DMS Shell Toggle (Niri)

[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Compositor: niri](https://img.shields.io/badge/compositor-niri-blue)](https://github.com/YaLTeR/niri)
[![Works on: Arch](https://img.shields.io/badge/tested%20on-Arch%20Linux-1793D1?logo=archlinux&logoColor=white)](https://archlinux.org/)
[![Works on: NixOS](https://img.shields.io/badge/tested%20on-NixOS-5277C3?logo=nixos&logoColor=white)](https://nixos.org/)

A one-command way to switch between [Noctalia](https://github.com/noctalia-dev/noctalia-shell) and [DankMaterialShell (DMS)](https://github.com/AvengeMedia/DankMaterialShell) on [niri](https://github.com/YaLTeR/niri), without logging out or hand-editing config files. Includes an `fzf`-based picker so you can see which shell is active and select the other one explicitly.

## Contents

- [The problem](#the-problem)
- [The fix: shell-toggle](#the-fix-shell-toggle)
- [NixOS compatibility](#nixos-compatibility)
- [Setup](#setup)
- [Usage](#usage)
- [Notes / gotchas](#notes--gotchas)

---

## The problem

Both Noctalia and DMS are full Quickshell-based shells for niri — bar, launcher, notifications, power menu, etc. Running both at once means duplicate bars, duplicate notification daemons, and keybind collisions, since niri's config is static and whichever shell's keybinds are active in `config.kdl` will "win" over the other, even if the other shell isn't running.

Specific issues hit along the way:

- Niri's `config.kdl` had Noctalia's keybinds (`Alt+Space`, `Alt+Escape`, `Mod+L`, `Mod+Shift+B`) hardcoded and *not* commented out. Since niri reads keybinds from its static config file, these bindings claimed those keys regardless of which shell was actually running — so DMS's own shortcut settings for the same keys (e.g. `Alt+Space` → Spotlight launcher) were silently dead.
- DMS writes its own keybinds to `~/.config/niri/dms/binds.kdl`, but that file only takes effect if it's `include`d from `config.kdl`. The include line was present but commented out, so DMS's keybinds were never actually loaded into niri.
- DMS is normally started via `dms.service` (systemd), but that unit depends on `graphical-session.target`, which only activates if niri itself is launched as a systemd service. Since niri here is started outside of systemd (e.g. from a TTY/display manager), that target never activates and `dms.service` fails with a "dependency" error. Solution: skip systemd for DMS entirely and start/stop it as a plain background process, same as Noctalia.

## The fix: `shell-toggle`

A bash script (`~/.local/bin/shell-toggle`) that:

1. Detects which shell is currently running (`pgrep -x noctalia`).
2. Shows an `fzf` picker listing both shells, with the currently active one shown in the prompt.
3. If you pick the shell that's already running, it does nothing. Otherwise it:
   - Kills the active shell.
   - Comments/uncomments the relevant lines in `~/.config/niri/config.kdl`:
     - The `spawn-at-startup "noctalia"` line, so the right shell autostarts on next login too.
     - Noctalia's hardcoded keybind lines, freeing those keys for DMS.
     - The `include "dms/binds.kdl"` line, so DMS's keybinds load only while DMS is active.
   - Reloads niri's config live (`niri msg action load-config-file`) — no logout needed.
   - Starts the newly selected shell as a detached background process (`setsid ... & disown`).

Requires [`fzf`](https://github.com/junegunn/fzf) to be installed.

<details>
<summary><code>~/.local/bin/shell-toggle</code> (click to expand)</summary>

```bash
#!/usr/bin/env bash
CONFIG=~/.config/niri/config.kdl

NOCTALIA_BINDS=(
    'Mod+L { spawn "sh" "-c" "noctalia msg session lock"; }'
    'Alt+Space { spawn "sh" "-c" "noctalia msg panel-toggle launcher"; }'
    'Alt+Escape { spawn "sh" "-c" "noctalia msg panel-toggle session"; }'
    'Mod+Shift+B { spawn "noctalia" "msg" "bar-toggle"; }'
)

switch_to_dms() {
    pkill -f "noctalia" 2>/dev/null
    sleep 1
    sed -i 's/^spawn-at-startup "noctalia"/\/\/ spawn-at-startup "noctalia"/' "$CONFIG"
    for line in "${NOCTALIA_BINDS[@]}"; do
        esc=$(printf '%s\n' "$line" | sed 's/[&/\]/\\&/g')
        sed -i "s|^    $esc|    // $esc|" "$CONFIG"
    done
    sed -i 's|^//include "dms/binds.kdl"|include "dms/binds.kdl"|' "$CONFIG"
    niri msg action load-config-file
    setsid dms run > /tmp/dms.log 2>&1 &
    disown
    sleep 1
    notify-send "Switched to DMS"
}

switch_to_noctalia() {
    pkill -f "dms run" 2>/dev/null
    sleep 1
    sed -i 's/^\/\/ spawn-at-startup "noctalia"/spawn-at-startup "noctalia"/' "$CONFIG"
    for line in "${NOCTALIA_BINDS[@]}"; do
        esc=$(printf '%s\n' "$line" | sed 's/[&/\]/\\&/g')
        sed -i "s|^    // $esc|    $esc|" "$CONFIG"
    done
    sed -i 's|^include "dms/binds.kdl"|//include "dms/binds.kdl"|' "$CONFIG"
    niri msg action load-config-file
    setsid noctalia > /tmp/noctalia.log 2>&1 &
    disown
    sleep 1
    notify-send "Switched to Noctalia"
}

CURRENT="DMS"
pgrep -f "noctalia" > /dev/null && CURRENT="Noctalia"

CHOICE=$(printf "Noctalia\nDMS" | fzf --prompt="Switch shell (current: $CURRENT) > " --height=10 --border --reverse)

if [ -z "$CHOICE" ]; then
    exit 0
fi

if [ "$CHOICE" = "Noctalia" ] && [ "$CURRENT" != "Noctalia" ]; then
    switch_to_noctalia
elif [ "$CHOICE" = "DMS" ] && [ "$CURRENT" != "DMS" ]; then
    switch_to_dms
fi
```

</details>

## NixOS compatibility

The script works unchanged on NixOS as long as `config.kdl` is a plain writable file (i.e. you're not managing it declaratively through home-manager). Two gotchas to watch for:

- **Shebang**: NixOS has no `/bin/bash` — everything lives under `/nix/store` and `/run/current-system/sw/bin/`. Use the portable shebang `#!/usr/bin/env bash` instead of `#!/bin/bash`, or the script fails to launch with "No such file or directory" / "not an executable command".
- **Process detection**: NixOS wraps binaries in `/nix/store`, which truncates the kernel-level process name (`/proc/PID/comm`, what `pgrep -x` matches against) to 15 characters — so `noctalia` becomes `.noctalia-wrapp`. This makes `pgrep -x noctalia` silently fail to detect a running Noctalia even though it's active. Use `pgrep -f "noctalia"` instead, which matches against the full command line and works identically on Arch and NixOS.

If you *do* use home-manager and `config.kdl` is Nix-store-managed (read-only), the `sed -i` calls will fail outright — that setup needs a different approach (a mutable symlink file that `config.kdl` includes, toggled by the script instead of editing the store-managed file directly).

Required packages: `fzf`, `libnotify` (`notify-send`), `procps` (`pgrep`/`pkill`) — install via `environment.systemPackages` or `nix-env` if not already present.

---

## Setup

1. Save the script to `~/.local/bin/shell-toggle` and make it executable: `chmod +x ~/.local/bin/shell-toggle`.
2. Make sure `dms.service` is disabled so it doesn't fight with the script: `systemctl --user disable dms`.
3. In `~/.config/niri/config.kdl`, keep the include for DMS's keybinds present but commented out by default: `//include "dms/binds.kdl"` (the script toggles it).
4. Optionally bind it to a key in niri:

```
Mod+Shift+S { spawn "shell-toggle"; }
```

Then reload with `niri msg action load-config-file`.

## Usage

```
shell-toggle
```

This opens an `fzf` picker showing "Noctalia" and "DMS", with the currently active one shown in the prompt text. Select the shell you want — picking the one already running does nothing; picking the other one switches. Press `Esc` to cancel without changes.

Since `fzf` needs a terminal, if you bind this to a niri key, launch it inside a terminal rather than headless:

```
Mod+Shift+S { spawn "kitty" "-e" "shell-toggle"; }
```

Then reload with `niri msg action load-config-file`.

---

## Notes / gotchas

- If you're on `fish` shell, heredocs (`<< 'EOF'`) aren't supported the same way as bash — drop into `bash` first when editing the script.
- DMS's power menu is bound via IPC: `dms ipc call powermenu toggle`. Bind it either by editing `dms/binds.kdl` directly, or through DMS's own in-app shortcut editor (Settings → Keyboard Shortcuts → **+**), which writes to the same file.
- Full DMS IPC reference: [DankMaterialShell/docs/IPC.md](https://github.com/AvengeMedia/DankMaterialShell/blob/master/docs/IPC.md)
