# dotfiles

My personal dotfiles. Quick install:

```sh
bash <(curl -fsSL https://github.com/yisonPylkita/dotfiles/raw/main/new.bash)
```

Run `bash new.bash --gui` after cloning for the CLI/server setup plus Alacritty and the Nerd Font. Supports Ubuntu 22.04/24.04/26.04 LTS and macOS.

Machine-specific settings and secrets belong in `~/.zsh_local` (ignored by Git); start from `.zsh_local.example`. Codex's DeepSeek worker setup lives outside this repo in `~/.codex`.
