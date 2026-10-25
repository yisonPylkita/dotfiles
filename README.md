# dotfiles

My personal dotfiles. Quick install:

```sh
bash <(curl -fsSL https://yisonpylkita.github.io/new.bash)
```

Append `--gui` to also install Alacritty and the Nerd Font. Supports Ubuntu 22.04/24.04/26.04 LTS and macOS.

The setup installs `cargo-binstall-latest`, which finds the newest crate version that has a prebuilt binary for the current platform before invoking `cargo-binstall`. It also installs `rustup-report`, which shows the disk usage of every installed Rust toolchain, the total count, and whether cleanup is recommended. It runs at the end of setup and after each `sau` update.

Machine-specific settings and secrets belong in `~/.zsh_local` (ignored by Git); start from `.zsh_local.example`. Codex's DeepSeek worker setup lives outside this repo in `~/.codex`.
