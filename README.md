# dotfiles

From this checkout, run the same setup on a fresh machine or rerun it to restore missing tools and align configuration:

```sh
bash ./new.bash
```

The setup supports macOS and Ubuntu 22.04, 24.04, and 26.04 LTS. It installs missing packages and tools, checks the Rust toolchain, and repairs shared configuration links. Use `sau` for updates. Add `--gui` to include Alacritty and the Nerd Font while keeping the same install and realignment behavior.

The setup installs `cargo-binstall-latest`, which finds the newest crate version that has a prebuilt binary for the current platform before invoking `cargo-binstall`. It also installs `rustup-report`, which shows the disk usage of every installed Rust toolchain, the total count, and whether cleanup is recommended. It runs at the end of setup and after each `sau` update.

Managed files are linked individually to this checkout, so unrelated files in configuration directories remain in place. Keep the checkout at its installed location, or rerun setup after moving it. Zsh paths follow `ZDOTDIR`, and XDG configuration links follow `XDG_CONFIG_HOME`.

A conflicting file or file symlink is moved into a private, timestamped backup under `~/.local/state/dotfiles` or `$XDG_STATE_HOME/dotfiles`; directory targets are refused. `manifest.tsv` records the original path, backup path, and original permission mode. Paths under `originals/` mirror their original locations. To restore an entry, remove its installed symlink, move the backup to its original path, and apply its recorded mode with `chmod` when present. Existing private overrides are copied into `private/`. Failed setup rolls back its changes; if restoration also fails, the backup is retained and its path is printed.

The setup creates empty private `~/.zsh_local`, `~/.fish_local`, and `~/.zshenv_local` files and `~/.config/dotfiles/setup.local.bash` when they are missing. It sources the hook after shared installs on every run. Pi JSON settings are copied as private files only when absent, so applications can update them without writing into this checkout.

Keep shared preferences in the tracked configuration. Put laptop-specific commands, work aliases, credentials, and optional tool paths in the ignored local files:

| Local file | Loaded by |
| --- | --- |
| `~/.zsh_local` | Interactive Zsh, after shared settings |
| `~/.fish_local` | Interactive Fish, after shared settings |
| `~/.zshenv_local` | All Zsh sessions, and again after login PATH setup; keep it quiet and idempotent |
| `~/.config/dotfiles/setup.local.bash` | Every setup run, for additional laptop-specific tooling; keep it safe to rerun |

Existing local files are never overwritten. Do not put secrets into the tracked configuration. `.zsh_local.example` shows the intended separation.

`sau` updates OS packages, Rust, and the shared Rust CLI tools. Its Rust steps use `~/.cargo` and `~/.rustup` from the home directory, so project Cargo settings cannot redirect system-wide updates. `cargo-binstall-latest` selects the newest release with a prebuilt binary instead of compiling these tools locally.
