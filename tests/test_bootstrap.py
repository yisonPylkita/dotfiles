import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASH = "/bin/bash"
FORMULAS = [
    "zsh",
    "fish",
    "tmux",
    "neovim",
    "jq",
    "fzf",
    "podman",
    "git-lfs",
    "htop",
    "python",
    "node",
    "fnm",
    "direnv",
    "uv",
    "cargo-binstall",
]
APT_PACKAGES = [
    "zsh",
    "fish",
    "tmux",
    "cmake",
    "neovim",
    "build-essential",
    "pkg-config",
    "openssl",
    "libssl-dev",
    "jq",
    "fzf",
    "curl",
    "git",
    "git-lfs",
    "htop",
    "ca-certificates",
    "unzip",
    "fontconfig",
    "python3",
    "python3-venv",
    "python3-pip",
    "pipx",
    "direnv",
    "nodejs",
    "npm",
]


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.fixture = self.root / "checkout"
        self.fixture.mkdir()
        self._copy_fixture()

    def tearDown(self):
        self.temp.cleanup()

    def _copy_fixture(self):
        files = [
            "new.bash",
            "setup-config.sh",
            ".zshrc",
            ".zshenv",
            ".zprofile",
            ".vimrc",
            ".config/fish/config.fish",
            ".config/zellij/config.kdl",
            ".config/alacritty/alacritty.toml",
            "nvim/init.vim",
            ".pi/agent/settings.json",
            ".pi/agent/trust.json",
            ".pi/agent/npm/package.json",
            ".pi/agent/extensions/eko24ive-pi-ask.json",
            ".pi/agent/extensions/pi-rtk-optimizer/config.json",
            "bin/dotfiles-rust-update",
            "bin/dotfiles-ai-build",
            "ai/AGENTS.md",
        ]
        for relative in files:
            source = ROOT / relative
            destination = self.fixture / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

        helper = self.fixture / "bin/cargo-binstall-latest"
        helper.write_text(
            "#!/bin/sh\n"
            'printf "%s\\n" "$1" >> "$RUST_CLI_LOG"\n'
            'case "$1" in\n'
            'starship) binary=starship ;;\n'
            'ripgrep) binary=rg ;;\n'
            'lsd) binary=lsd ;;\n'
            'bat) binary=bat ;;\n'
            'gitui) binary=gitui ;;\n'
            'zellij) binary=zellij ;;\n'
            '*) exit 72 ;;\n'
            'esac\n'
            'printf "#!/bin/sh\\nexit 0\\n" > "$HOME/.cargo/bin/$binary"\n'
            'chmod 755 "$HOME/.cargo/bin/$binary"\n'
        )
        helper.chmod(0o755)

    def _write_shim(self, directory, name, body):
        path = directory / name
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o755)
        return path

    def _environment(self, system):
        shim_dir = self.root / "shims"
        shim_dir.mkdir(exist_ok=True)
        cargo_bin = self.home / ".cargo/bin"
        cargo_bin.mkdir(parents=True, exist_ok=True)
        (cargo_bin / "env").write_text('export PATH="$HOME/.cargo/bin:$PATH"\n')
        call_log = self.root / "calls.log"
        rustup_log = self.root / "rustup.log"
        rust_cli_log = self.root / "rust-cli.log"
        hook_count = self.root / "hook-count"
        formula_state = self.root / "brew-formulas"
        cask_state = self.root / "brew-casks"
        apt_state = self.root / "apt-packages"
        apt_index = self.root / "apt-index"
        npm_state = self.root / "npm-global"
        rustup_default = self.root / "rustup-default"
        formula_state.touch()
        cask_state.touch()
        apt_state.touch()
        npm_state.touch()
        rustup_default.touch()

        self._write_shim(
            shim_dir,
            "uname",
            'printf "%s\\n" "$TEST_OS"',
        )
        self._write_shim(
            shim_dir,
            "brew",
            'printf "brew %s\\n" "$*" >> "$CALL_LOG"\n'
            'case "$1" in\n'
            'shellenv) printf ":\\n" ;;\n'
            'list)\n'
            '  if [ "$2" = "--formula" ]; then state=$BREW_FORMULAS; package=$3; else state=$BREW_CASKS; package=$3; fi\n'
            '  if grep -Fqx "$package" "$state"; then exit 0; fi\n'
            '  exit 1\n'
            '  ;;\n'
            'install)\n'
            '  if [ "${FAIL_BREW_INSTALL:-0}" = 1 ]; then exit 43; fi\n'
            '  if [ "$2" = "--cask" ]; then printf "%s\\n" "$3" >> "$BREW_CASKS"; else shift; for package do printf "%s\\n" "$package" >> "$BREW_FORMULAS"; done; fi\n'
            '  ;;\n'
            '*) exit 0 ;;\n'
            'esac',
        )
        self._write_shim(
            shim_dir,
            "sudo",
            'printf "sudo %s\\n" "$*" >> "$CALL_LOG"\nexec "$@"',
        )
        self._write_shim(
            shim_dir,
            "apt-get",
            'printf "apt-get %s\\n" "$*" >> "$CALL_LOG"\n'
            'case "$1" in\n'
            'update) touch "$APT_INDEX_FILE" ;;\n'
            'install)\n'
            '  if [ "${FAIL_APT_INSTALL:-0}" = 1 ]; then exit 47; fi\n'
            '  shift\n'
            '  [ "$1" = "-y" ] && shift\n'
            '  for package do printf "%s\\n" "$package" >> "$APT_PACKAGES"; done\n'
            '  ;;\n'
            '*) exit 0 ;;\n'
            'esac',
        )
        self._write_shim(
            shim_dir,
            "dpkg-query",
            'for package do last=$package; done\n'
            'if grep -Fqx "$last" "$APT_PACKAGES"; then printf "ii \\n"; exit 0; fi\n'
            'exit 1',
        )
        self._write_shim(
            shim_dir,
            "find",
            'if [ "$1" = "/var/lib/apt/lists" ]; then\n'
            '  if [ -f "$APT_INDEX_FILE" ]; then printf "/var/lib/apt/lists/mock\\n"; fi\n'
            '  exit 0\n'
            'fi\n'
            f'exec {shutil.which("find")} "$@"',
        )
        self._write_shim(
            shim_dir,
            "lsb_release",
            'case "$1" in -si) printf "Ubuntu\\n" ;; -sr) printf "24.04\\n" ;; esac',
        )
        self._write_shim(
            shim_dir,
            "getent",
            'printf "%s:x:1000:1000::%s:%s\\n" "$TEST_LOGIN_USER" "$HOME" "$ZSH_PATH"',
        )
        self._write_shim(
            shim_dir,
            "dscl",
            'printf "UserShell: %s\\n" "$ZSH_PATH"',
        )
        self._write_shim(
            shim_dir,
            "id",
            'if [ "$1" = "-un" ]; then printf "%s\\n" "$TEST_LOGIN_USER"; else exec /usr/bin/id "$@"; fi',
        )
        self._write_shim(
            shim_dir,
            "git",
            'printf "git %s\\n" "$*" >> "$CALL_LOG"\n'
            'case "$1" in\n'
            'config) if [ "$2" = "--global" ] && [ "$3" = "--get" ]; then exit 0; fi ;;\n'
            'lfs) exit 0 ;;\n'
            'clone)\n'
            '  for destination do target=$destination; done\n'
            '  mkdir -p "$target"\n'
            '  case "$target" in\n'
            '    */.fzf)\n'
            '      printf \'%s\\n\' \'#!/bin/sh\' \'printf "fzf-install\\n" >> "$CALL_LOG"\' > "$target/install"\n'
            '      chmod 755 "$target/install"\n'
            '      ;;\n'
            '  esac\n'
            '  ;;\n'
            'esac\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "git-lfs",
            'printf "git-lfs %s\\n" "$*" >> "$CALL_LOG"\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "curl",
            'printf "curl %s\\n" "$*" >> "$CALL_LOG"\nexit 91',
        )
        self._write_shim(
            shim_dir,
            "ssh",
            'printf "ssh %s\\n" "$*" >> "$CALL_LOG"\nexit 1',
        )
        self._write_shim(
            shim_dir,
            "ssh-keygen",
            'printf "ssh-keygen %s\\n" "$*" >> "$CALL_LOG"\nexit 92',
        )
        self._write_shim(
            shim_dir,
            "chsh",
            'printf "chsh %s\\n" "$*" >> "$CALL_LOG"\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "fnm",
            'printf "fnm %s\\n" "$*" >> "$CALL_LOG"\nif [ "$1" = env ]; then printf ":\\n"; fi\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "node",
            'printf "node %s\\n" "$*" >> "$CALL_LOG"\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "npm",
            'printf "npm %s\\n" "$*" >> "$CALL_LOG"\n'
            'case "$1" in\n'
            'config) exit 0 ;;\n'
            'list)\n'
            '  global=false\n'
            '  for argument do [ "$argument" = "--global" ] && global=true; package=$argument; done\n'
            '  if [ "$global" = true ]; then grep -Fqx "$package" "$NPM_GLOBAL_STATE"; else [ -f package.json ] && [ -f node_modules/.setup-installed ]; fi\n'
            '  ;;\n'
            'install)\n'
            '  global=false\n'
            '  for argument do [ "$argument" = "--global" ] && global=true; package=$argument; done\n'
            '  if [ "$global" = true ]; then printf "%s\\n" "$package" >> "$NPM_GLOBAL_STATE"; else [ -f package.json ] || exit 49; mkdir -p node_modules; touch node_modules/.setup-installed; fi\n'
            '  ;;\n'
            '*) exit 0 ;;\n'
            'esac',
        )
        self._write_shim(
            shim_dir,
            "pipx",
            'printf "pipx %s\\n" "$*" >> "$CALL_LOG"\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "uv",
            'printf "uv %s\\n" "$*" >> "$CALL_LOG"\nexit 0',
        )
        self._write_shim(
            shim_dir,
            "cargo-binstall",
            'printf "cargo-binstall %s\\n" "$*" >> "$CALL_LOG"\nexit 0',
        )
        for name in ["zsh", "starship", "ripgrep", "lsd", "bat", "gitui", "zellij"]:
            self._write_shim(shim_dir, name, "exit 0")

        rustup = cargo_bin / "rustup"
        rustup.write_text(
            "#!/bin/sh\n"
            'printf "%s|%s|%s|%s|%s|%s\\n" "$*" "$PWD" "$CARGO_HOME" "$RUSTUP_HOME" "$CARGO_INSTALL_ROOT" "${RUSTUP_TOOLCHAIN-unset}" >> "$RUSTUP_LOG"\n'
            'case "$1" in\n'
            'toolchain)\n'
            '  if [ "$2" = list ]; then\n'
            '    if [ -f "$RUSTUP_DEFAULT" ]; then printf "stable-aarch64-apple-darwin (default)\\n"; fi\n'
            '    exit 0\n'
            '  fi\n'
            '  if [ "$2" = install ]; then touch "$RUSTUP_INSTALLED"; fi\n'
            '  ;;\n'
            'default) touch "$RUSTUP_DEFAULT" ;;\n'
            '*) exit 0 ;;\n'
            'esac',
        )
        rustup.chmod(0o755)
        (self.root / "rustup-installed").unlink(missing_ok=True)
        rustup_default.unlink()

        env = {
            "HOME": str(self.home),
            "PATH": os.pathsep.join(
                [str(shim_dir), "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            ),
            "SHELL": "/bin/bash",
            "USER": "stale-user-value",
            "TEST_OS": system,
            "TEST_LOGIN_USER": "bootstrap-user",
            "ZSH_PATH": str(shim_dir / "zsh"),
            "CALL_LOG": str(call_log),
            "RUSTUP_LOG": str(rustup_log),
            "RUST_CLI_LOG": str(rust_cli_log),
            "HOOK_COUNT": str(hook_count),
            "BREW_FORMULAS": str(formula_state),
            "BREW_CASKS": str(cask_state),
            "APT_PACKAGES": str(apt_state),
            "APT_INDEX_FILE": str(apt_index),
            "NPM_GLOBAL_STATE": str(npm_state),
            "RUSTUP_DEFAULT": str(rustup_default),
            "RUSTUP_INSTALLED": str(self.root / "rustup-installed"),
            "RUSTUP_TOOLCHAIN": "project-toolchain",
            "CARGO_HOME": str(self.root / "project-cargo"),
            "RUSTUP_HOME": str(self.root / "project-rustup"),
            "CARGO_INSTALL_ROOT": str(self.root / "project-install"),
        }
        return env

    def _run(self, env, *arguments, script=None):
        return subprocess.run(
            [BASH, "-x", str(script or self.fixture / "new.bash"), *arguments],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    def _install_hook(self):
        local_dir = self.home / ".config/dotfiles"
        local_dir.mkdir(parents=True, exist_ok=True)
        hook = local_dir / "setup.local.bash"
        hook_contents = (
            'case "$-" in *x*) exit 80 ;; esac\n'
            'count=0\n'
            '[ ! -f "$HOOK_COUNT" ] || count=$(cat "$HOOK_COUNT")\n'
            'printf "%s\\n" "$((count + 1))" > "$HOOK_COUNT"\n'
        )
        hook.write_text(hook_contents)
        (self.home / ".zsh_local").write_text("private zsh setting\n")
        (self.home / ".fish_local").write_text("private fish setting\n")
        (self.home / ".zshenv_local").write_text("private env setting\n")
        return hook, hook_contents

    def _drift_zshrc(self):
        zshrc = self.home / ".zshrc"
        zshrc.unlink()
        zshrc.write_text("local drift\n")

    def test_macos_gui_first_run_and_repeat_reconcile_without_upgrades(self):
        env = self._environment("Darwin")
        formulas = [package for package in FORMULAS if package != "jq"]
        Path(env["BREW_FORMULAS"]).write_text("\n".join(formulas) + "\n")
        Path(env["BREW_CASKS"]).write_text("alacritty\nfont-caskaydia-cove-nerd-font\n")
        shutil.copytree(self.fixture, self.home / "dotfiles")
        download_dir = self.root / "download"
        download_dir.mkdir()
        download_script = download_dir / "new.bash"
        shutil.copy2(self.fixture / "new.bash", download_script)
        hook, hook_contents = self._install_hook()

        first = self._run(env, "--gui", script=download_script)
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertEqual((self.home / ".zsh_local").read_text(), "private zsh setting\n")
        self.assertEqual(hook.read_text(), hook_contents)
        self.assertEqual(Path(env["HOOK_COUNT"]).read_text(), "1\n")
        self.assertTrue((self.home / ".config/alacritty/alacritty.toml").is_symlink())
        self.assertTrue((self.home / ".config/alacritty/themes").is_dir())
        self.assertEqual(Path(env["RUST_CLI_LOG"]).read_text().splitlines(), ["ripgrep"])
        self.assertIn("toolchain list", Path(env["RUSTUP_LOG"]).read_text())
        self.assertIn("toolchain install stable", Path(env["RUSTUP_LOG"]).read_text())
        self.assertIn("default stable", Path(env["RUSTUP_LOG"]).read_text())
        self.assertEqual(
            Path(env["RUSTUP_LOG"]).read_text().splitlines()[0].split("|"),
            [
                "toolchain list",
                str(self.home),
                str(self.home / ".cargo"),
                str(self.home / ".rustup"),
                str(self.home / ".cargo"),
                "unset",
            ],
        )
        self.assertIn("brew install jq", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("brew install zsh", Path(env["CALL_LOG"]).read_text())
        self.assertIn("brew install --cask codex", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("brew install --cask alacritty", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("brew install --cask font-caskaydia-cove-nerd-font", Path(env["CALL_LOG"]).read_text())

        self._drift_zshrc()
        second = self._run(env, "--gui", script=download_script)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(Path(env["HOOK_COUNT"]).read_text(), "2\n")
        self.assertTrue((self.home / ".zshrc").is_symlink())
        backups = list((self.home / ".local/state/dotfiles").glob("dotfiles-setup-*"))
        self.assertEqual(len(backups), 1)
        backed_up = backups[0] / "originals" / str(self.home.resolve()).lstrip("/") / ".zshrc"
        self.assertEqual(backed_up.read_text(), "local drift\n")
        self.assertEqual(Path(env["RUST_CLI_LOG"]).read_text().splitlines(), ["ripgrep"])
        self.assertEqual(Path(env["RUSTUP_LOG"]).read_text().count("toolchain install stable"), 1)
        self.assertEqual(Path(env["CALL_LOG"]).read_text().count("brew install "), 2)
        self.assertNotIn("brew update", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("brew upgrade", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("apt-get upgrade", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("curl ", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("ssh ", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("ssh-keygen ", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("chsh ", Path(env["CALL_LOG"]).read_text())
        self.assertEqual(Path(env["NPM_GLOBAL_STATE"]).read_text().splitlines(), ["@earendil-works/pi-coding-agent"])

    def test_macos_keeps_configured_zsh_when_another_zsh_is_first_on_path(self):
        env = self._environment("Darwin")
        Path(env["BREW_FORMULAS"]).write_text("\n".join(FORMULAS) + "\n")
        system_bin = self.root / "system-bin"
        system_bin.mkdir()
        self._write_shim(system_bin, "zsh", "exit 0")
        env["ZSH_PATH"] = str(system_bin / "zsh")
        result = self._run(env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = Path(env["CALL_LOG"]).read_text()
        self.assertNotIn("chsh ", calls)
        self.assertNotIn("sudo ", calls)

    def test_macos_changes_login_shell_when_it_is_not_zsh(self):
        env = self._environment("Darwin")
        Path(env["BREW_FORMULAS"]).write_text("\n".join(FORMULAS) + "\n")
        system_bin = self.root / "system-bin"
        system_bin.mkdir()
        self._write_shim(system_bin, "bash", "exit 0")
        env["ZSH_PATH"] = str(system_bin / "bash")
        result = self._run(env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("sudo chsh -s", Path(env["CALL_LOG"]).read_text())

    def test_macos_skips_font_cask_when_font_files_already_exist(self):
        env = self._environment("Darwin")
        Path(env["BREW_FORMULAS"]).write_text("\n".join(FORMULAS) + "\n")
        Path(env["BREW_CASKS"]).write_text("alacritty\n")
        fonts = self.home / "Library/Fonts"
        fonts.mkdir(parents=True)
        (fonts / "CaskaydiaCoveNerdFont-Bold.ttf").write_text("font")
        result = self._run(env, "--gui")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("font-caskaydia-cove-nerd-font", Path(env["CALL_LOG"]).read_text())

    def test_macos_skips_codex_cask_when_codex_is_already_on_path(self):
        env = self._environment("Darwin")
        Path(env["BREW_FORMULAS"]).write_text("\n".join(FORMULAS) + "\n")
        self._write_shim(self.root / "shims", "codex", "exit 0")
        result = self._run(env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("--cask codex", Path(env["CALL_LOG"]).read_text())

    def test_ubuntu_gui_installs_only_missing_packages_and_reruns_safely(self):
        env = self._environment("Linux")
        Path(env["APT_PACKAGES"]).write_text("zsh\ncurl\ngit\n")
        hook, hook_contents = self._install_hook()
        fonts = self.home / ".local/share/fonts"
        fonts.mkdir(parents=True)
        (fonts / "CaskaydiaCoveNerdFont-Regular.ttf").write_text("font")

        first = self._run(env, "--gui")
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertEqual(Path(env["HOOK_COUNT"]).read_text(), "1\n")
        self.assertTrue((self.home / ".config/alacritty/themes").is_dir())
        self.assertTrue((self.home / ".fzf/install").is_file())
        self.assertIn("fzf-install", Path(env["CALL_LOG"]).read_text())
        calls = Path(env["CALL_LOG"]).read_text().splitlines()
        self.assertEqual(sum(line.startswith("apt-get update") for line in calls), 1)
        self.assertIn("apt-get install -y alacritty", Path(env["CALL_LOG"]).read_text())
        first_install = next(
            line for line in calls if line.startswith("apt-get install -y ") and "alacritty" not in line
        )
        self.assertNotIn(" zsh", first_install)
        self.assertNotIn(" curl", first_install)
        self.assertEqual(
            Path(env["NPM_GLOBAL_STATE"]).read_text().splitlines(),
            ["@earendil-works/pi-coding-agent", "@openai/codex"],
        )

        self._drift_zshrc()
        second = self._run(env, "--gui")
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(Path(env["HOOK_COUNT"]).read_text(), "2\n")
        calls = Path(env["CALL_LOG"]).read_text().splitlines()
        self.assertEqual(sum(line.startswith("apt-get update") for line in calls), 1)
        self.assertEqual(sum(line.startswith("apt-get install -y ") for line in calls), 2)
        self.assertEqual(sum(line.startswith("git clone ") for line in calls), 2)
        self.assertEqual(sum(line.startswith("fzf-install") for line in calls), 1)
        self.assertNotIn("apt-get upgrade", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("curl ", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("ssh ", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("ssh-keygen ", Path(env["CALL_LOG"]).read_text())
        self.assertNotIn("chsh ", Path(env["CALL_LOG"]).read_text())
        self.assertEqual(hook.read_text(), hook_contents)

    def test_required_package_install_failure_stops_bootstrap(self):
        env = self._environment("Darwin")
        env["FAIL_BREW_INSTALL"] = "1"
        result = self._run(env)
        self.assertEqual(result.returncode, 43, result.stdout + result.stderr)
        self.assertNotIn("All done", result.stdout)
        self.assertIn("brew install", Path(env["CALL_LOG"]).read_text())

    def test_macos_default_setup_installs_cli_and_pi_dependencies(self):
        env = self._environment("Darwin")
        Path(env["BREW_FORMULAS"]).write_text("\n".join(FORMULAS) + "\n")
        result = self._run(env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = Path(env["CALL_LOG"]).read_text()
        self.assertIn("brew install --cask codex", calls)
        self.assertNotIn("alacritty", calls)
        self.assertTrue((self.home / ".pi/agent/npm/node_modules/.setup-installed").is_file())
        self.assertFalse((self.home / ".pi/agent/node_modules").exists())
        self.assertEqual(calls.count("npm install --ignore-scripts"), 1)
        second = self._run(env)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(Path(env["CALL_LOG"]).read_text().count("npm install --ignore-scripts"), 1)

    def test_obsolete_config_only_option_is_rejected_and_hidden_from_help(self):
        help_result = subprocess.run(
            [BASH, str(ROOT / "new.bash"), "--help"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertNotIn("config-only", help_result.stdout)
        rejected = subprocess.run(
            [BASH, str(ROOT / "new.bash"), "--config-only"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(rejected.returncode, 64)
        self.assertIn("Unknown option: --config-only", rejected.stderr)


if __name__ == "__main__":
    unittest.main()
