# Dump Script for Linux

### Script to automatically set Pam Usb / Usb Lock & Power Shutdown / Screen Of Intruder / Dotfile / Package & App / Custom Package & Binary / AI / N8n / Git / Grub & Plymouth / Wayland

![Loading screen](docs/img/loading.png)

> [!WARNING]
> The script must be run with `sudo` from the user account (the config files belong to `$SUDO_USER`).

| Family | Distributions (`ID` / `ID_LIKE` of `/etc/os-release`) | Packages |
| ------ | ------------------------------------------------------ | -------- |
| fedora-like | Fedora, RHEL, CentOS, Rocky, Alma... | `dnf` |
| debian-like | Debian, Ubuntu, Mint, Pop!_OS... | `apt` |
| arch-like | Arch, Manjaro, EndeavourOS... | `pacman` |

> [!NOTE]
> The package names are translated for each family, a package missing from the repositories of the distribution is
> reported and skipped (or installed another way: `gum` from the Charm repository, `asciiquarium` from its sources...).

Clone the repository:
```bash
git clone https://github.com/TsukiNi22/dump.git ~/dump
```

Launch the installation:
```bash
cd ~/dump
sudo make
```

> [!TIP]
> Once the dotfiles are installed, the `dump` alias of the zshrc runs `sudo make` in this repository (path written by the Dotfile setup, wherever it was cloned).

> [!NOTE]
> A loading screen runs the system update (fixed title, logs below), then everything runs in one `fzf` window: a
> setup runs in the background with its output shown live on the right (details, status and output of its last
> run, `ctrl-l`: whole output), and its questions are asked in the list of the window. Every setup can also be run
> alone (`gum` prompts, `fzf` without gum): `sudo bash Linux/<setup>/launch.sh`.

| Menu (details of the hovered setup) | Setup running (list locked, live output) | Question of a setup |
| ----------------------------------- | ---------------------------------------- | ------------------- |
| ![Menu](docs/img/menu.png) | ![Setup running](docs/img/running.png) | ![Question](docs/img/question.png) |

## Content of Dotfile, Package & App, Custom Package & AI

### Dotfile
| Config | Content |
| ------ | ------- |
| `Zsh` | `.zshrc` with `Oh-My-Zsh`, `zoxide`, aliases (git, make, cmake, docker...) |
| `Neovim` | `lazy.nvim`, `rose-pine`, `nvim-treesitter`, `nvim-cmp`, Xartania / Epitech headers & protos |
| `Fastfetch` | Random picture at each launch (`rdm_img.sh`, `chafa`) |
| `Tmux` | `zsh` as default shell |
| `Git` | Global ignore (`~/.config/git/ignore`) |

### Package
`gcc`, `clang`, `cmake`, `ccache`, `gtest`, `valgrind`, `docker`, `tmux`, `sl`, `csfml`, `binwalk`, `john`, `gobuster`,
`hydra`, `asciiquarium`, `gh`, `ripgrep`

### App
`vscode`, `qBittorrent`, `vesktop`, `sober`, `wireshark`, `Telegram`

### Custom Package & Binary
| Name | Content |
| ---- | ------- |
| [`libutils`](https://github.com/TsukiNi22/libutils) | TsukiNi22 rpm / deb mirror (built from the sources on arch), every build (optimized, debug, asan + headers) |
| `xstyle` | Coding style checker of the [ai-utils](https://github.com/TsukiNi22/ai-utils) repository (`~/.local/bin`) |

### AI
| Name | Content |
| ---- | ------- |
| `Claude Code` | Native installer (`~/.local/bin/claude`) |
| `Ollama` | Official installer (`/usr/local/bin/ollama`, `ollama.service`) |
| `Skills` | Every skill of the [ai-utils](https://github.com/TsukiNi22/ai-utils) repository in `~/.claude/skills` + their tools |
| `Skills context` | `CLAUDE.md`, `RTK.md`, hooks and `rtk` (branch `context` of the ai-utils repository) |

### Git
Git user config, `~/delivery` & `~/personal_delivery`, `~/.ssh/git` key, then clone (https, push with ssh) any of:

> [!NOTE]
> The `~/.ssh/git` key is an `ed25519` key (the strongest type of OpenSSH and GitHub, no post-quantum signature key
> exists for ssh yet) or an `ed25519-sk` key on a FIDO2 security key, protected by a passphrase (256 KDF rounds).
> The quantum resistance comes from the key exchange: the github host of `~/.ssh/config` only allows the
> post-quantum hybrids `mlkem768x25519-sha256` and `sntrup761x25519-sha512`.

| Repository | Folder |
| ---------- | ------ |
| `libutils`, `cpp_project_template` | `~/personal_delivery/cpp/` |
| `ai-utils` | `~/personal_delivery/other/ai-utils` (used by the Custom Package & AI setups) |
| `docker-image` | `~/personal_delivery/other/docker-image` |
| Other links (one per line) | Chosen folder (default: `~/personal_delivery`) |

> [!CAUTION]
> The Pam Usb setup requires a main usb key (password AND one of the main usbs) in the auth stack: a marked block at the start of
> `/etc/pam.d/system-auth` (+ `password-auth` on fedora-like, rebuilt by `authselect` first) or a `pam-auth-update`
> profile on debian-like. It is only enabled when `pam_usb.so` is installed with all its libraries.

### Wayland
[Hyprland](https://hypr.land) and the configs of the [wayland-desktop](https://github.com/TsukiNi22/wayland-desktop)
repository (`install.sh` of its `main` branch), chosen when the setup starts:

| Choice | Content |
| ------ | ------- |
| `Wayland` | every style + a switcher in the top bar (click: menu, scroll: next / previous, `Super+Shift+W`), GNOME-like overview (`Super`), live wallpapers |
| `System`, `Dev / low level`, `Ado / blue rose`, `Terminal / better-tty`, `Miku`, `Photographer` | one style alone |
| `Remove the config` | remove the configs, the saved files are put back |

| Family | Hyprland & hyprlock |
| ------ | ------------------- |
| fedora-like | copr `sdegler/hyprland` (not in the Fedora repositories) |
| debian-like | repositories of the distribution (Debian 13+, recent Ubuntu), skipped when missing |
| arch-like | official repositories |

> [!NOTE]
> The other packages: `waybar`, `wofi`, `kitty`, `swaybg`, `mako`, `grim`, `slurp`, `wl-clipboard`, `brightnessctl`,
> `playerctl`, `nautilus`, `btop`, the Adwaita cursor, the JetBrains Mono, Font Awesome, Noto CJK, Adwaita Sans, Noto Serif
> and Noto Sans Symbols 2 fonts, `quickshell` (overview), `cava` (music bars), python GTK, WebKit 4.1 and `gtk-layer-shell`
> (live wallpapers); one missing in the repositories of the family is skipped (the overview falls back to the wofi launcher,
> the wallpaper to the still image). Log out and choose Hyprland at the login screen.

## Get Information about usb id (`vendor-id` / `device-id`)

The usb is chosen from the `lsusb` list in the menu, or written by hand with `Manual`:
```
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 001 Device 003: ID 5986:211b Bison Electronics Inc. HD Webcam
Bus 001 Device 005: ID 8087:0033 Intel Corp. AX211 Bluetooth
Bus 001 Device 012: ID 04d9:a09f Holtek Semiconductor, Inc. E-Signal LUOM G10 Mechanical Gaming Mouse
Bus 001 Device 019: ID ffff:5678 USB Disk 2.0
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
```

For the `USB Disk 2.0` the `vendor-id` is `ffff` and the `device-id` is `5678`.

| Usb | Used by |
| --- | ------- |
| main keys (`vendor-id:device-id`, as many as wanted) | Pam Usb (any of them unlocks), Usb Lock & Power Shutdown (lock when the last one is removed), Screen Of Intruder (picture when none is plugged) |
| cancel keys (optional, as many as wanted) | Usb Lock & Power Shutdown and Screen Of Intruder: one plugged -> nothing happens |

> [!IMPORTANT]
> A key is either a main key or a cancel key, never both: the selection refuses a key already used by the other role
> and the setups refuse a state where a key is in both lists. A cancel key never unlocks the session (Pam Usb).

> [!NOTE]
> The usb keys are optional (`Usb Keys` in the menu). Without a plugged main usb, the 3 usb setups are marked
> `(usb key needed)` and propose to choose it when they start, or to only deactivate what they installed
> (Usb Lock & Power Shutdown: one of them or both).
