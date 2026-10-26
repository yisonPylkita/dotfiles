import os
import shlex
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")


class SetupConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home)
        self.env.pop("XDG_CONFIG_HOME", None)
        self.env.pop("XDG_STATE_HOME", None)
        self.env.pop("ZDOTDIR", None)

    def tearDown(self):
        self.temp.cleanup()

    def run_helper(self, *args, env=None, check=True):
        run_env = self.env.copy()
        if env:
            run_env.update(env)
        result = subprocess.run(
            [BASH, str(ROOT / "setup-config.sh"), *args],
            cwd=ROOT,
            env=run_env,
            text=True,
            capture_output=True,
            timeout=30,
        )
        if check and result.returncode != 0:
            self.fail(result.stdout + result.stderr)
        return result

    def test_first_install_and_rerun_are_idempotent(self):
        first = self.run_helper()
        links = {
            self.home / ".zshrc": ROOT / ".zshrc",
            self.home / ".zshenv": ROOT / ".zshenv",
            self.home / ".zprofile": ROOT / ".zprofile",
            self.home / ".config/fish/config.fish": ROOT / ".config/fish/config.fish",
            self.home / ".config/zellij/config.kdl": ROOT / ".config/zellij/config.kdl",
            self.home / ".config/nvim/init.vim": ROOT / "nvim/init.vim",
            self.home / ".vimrc": ROOT / ".vimrc",
            self.home / ".local/bin/cargo-binstall-latest": ROOT / "bin/cargo-binstall-latest",
        }
        rust_update = ROOT / "bin/dotfiles-rust-update"
        if rust_update.exists():
            links[self.home / ".local/bin/dotfiles-rust-update"] = rust_update
        links[self.home / ".local/bin/dotfiles-ai-build"] = ROOT / "bin/dotfiles-ai-build"
        generated = self.home.resolve() / ".config/ai/AGENTS.md"
        links[self.home / ".claude/CLAUDE.md"] = generated
        links[self.home / ".codex/AGENTS.md"] = generated
        for destination, source in links.items():
            self.assertTrue(destination.is_symlink())
            self.assertEqual(os.readlink(destination), str(source))
        self.assertEqual(generated.read_bytes(), (ROOT / "ai/AGENTS.md").read_bytes())
        self.assertNotIn("Backups stored under", first.stdout)
        self.assertFalse((self.home / ".config/alacritty/alacritty.toml").exists())

        local_files = [
            self.home / ".zsh_local",
            self.home / ".fish_local",
            self.home / ".zshenv_local",
            self.home / ".config/dotfiles/setup.local.bash",
        ]
        for path in local_files:
            self.assertTrue(path.is_file())
            self.assertFalse(path.is_symlink())
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(path.read_bytes(), b"")

        pi_files = [
            (self.home / ".pi/agent/settings.json", ROOT / ".pi/agent/settings.json"),
            (self.home / ".pi/agent/trust.json", ROOT / ".pi/agent/trust.json"),
            (self.home / ".pi/agent/npm/package.json", ROOT / ".pi/agent/npm/package.json"),
            (
                self.home / ".pi/agent/extensions/eko24ive-pi-ask.json",
                ROOT / ".pi/agent/extensions/eko24ive-pi-ask.json",
            ),
            (
                self.home / ".pi/agent/extensions/pi-rtk-optimizer/config.json",
                ROOT / ".pi/agent/extensions/pi-rtk-optimizer/config.json",
            ),
        ]
        for destination, source in pi_files:
            self.assertTrue(destination.is_file())
            self.assertFalse(destination.is_symlink())
            self.assertEqual(destination.read_bytes(), source.read_bytes())
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)

        second = self.run_helper()
        self.assertNotIn("Backups stored under", second.stdout)
        self.assertEqual(os.readlink(self.home / ".zshrc"), str(ROOT / ".zshrc"))

    def test_backup_preserves_bytes_links_and_private_overrides(self):
        config_home = self.home / "config directory"
        zsh_dir = self.home / "zsh directory"
        state_home = self.home / "state directory"
        config_home.mkdir()
        zsh_dir.mkdir()
        state_home.mkdir()
        (config_home / "fish").mkdir()
        (zsh_dir / ".zshrc").write_bytes(b"old zsh config\n")
        (zsh_dir / ".zshrc").chmod(0o640)
        dangling_target = self.root / "missing target"
        os.symlink(str(dangling_target), config_home / "fish/config.fish")
        (self.home / ".vimrc").symlink_to(self.root / "local vimrc file")
        (self.home / ".zsh_local").write_text("private zsh\n")
        (self.home / ".fish_local").write_text("private fish\n")
        (self.home / ".zshenv_local").write_text("private zshenv\n")
        (self.home / ".config/dotfiles").mkdir(parents=True)
        hook = self.home / ".config/dotfiles/setup.local.bash"
        hook.write_text("private hook\n")

        result = self.run_helper(
            env={
                "XDG_CONFIG_HOME": str(config_home),
                "XDG_STATE_HOME": str(state_home),
                "ZDOTDIR": str(zsh_dir),
            }
        )
        self.assertIn("Backups stored under", result.stdout)
        backup_dir = Path(result.stdout.split("Backups stored under ", 1)[1].strip())
        self.assertTrue(backup_dir.is_dir())
        self.assertEqual(stat.S_IMODE(backup_dir.stat().st_mode), 0o700)

        physical_home = self.home.resolve()
        physical_config = config_home.resolve()
        physical_zsh = zsh_dir.resolve()
        physical_hook = hook.resolve()
        old_zsh = backup_dir / "originals" / str(physical_zsh).lstrip("/") / ".zshrc"
        old_fish = backup_dir / "originals" / str(physical_config).lstrip("/") / "fish/config.fish"
        old_vimrc = backup_dir / "originals" / str(physical_home).lstrip("/") / ".vimrc"
        old_local = backup_dir / "private" / str(physical_home).lstrip("/") / ".zsh_local"
        old_fish_local = backup_dir / "private" / str(physical_home).lstrip("/") / ".fish_local"
        old_zshenv_local = backup_dir / "private" / str(physical_home).lstrip("/") / ".zshenv_local"
        old_hook = backup_dir / "private" / str(physical_hook).lstrip("/")
        self.assertEqual(old_zsh.read_bytes(), b"old zsh config\n")
        self.assertEqual(stat.S_IMODE(old_zsh.stat().st_mode), 0o600)
        self.assertTrue(old_fish.is_symlink())
        self.assertEqual(os.readlink(old_fish), str(dangling_target))
        self.assertTrue(old_vimrc.is_symlink())
        self.assertEqual(os.readlink(old_vimrc), str(self.root / "local vimrc file"))
        self.assertEqual(old_local.read_text(), "private zsh\n")
        self.assertEqual(stat.S_IMODE(old_local.stat().st_mode), 0o600)
        self.assertEqual(old_fish_local.read_text(), "private fish\n")
        self.assertEqual(old_zshenv_local.read_text(), "private zshenv\n")
        self.assertEqual(old_hook.read_text(), "private hook\n")
        self.assertEqual((self.home / ".zsh_local").read_text(), "private zsh\n")
        self.assertEqual((self.home / ".fish_local").read_text(), "private fish\n")
        self.assertEqual((self.home / ".zshenv_local").read_text(), "private zshenv\n")
        self.assertEqual(hook.read_text(), "private hook\n")
        self.assertIn(str(physical_zsh / ".zshrc"), (backup_dir / "manifest.tsv").read_text())
        self.assertTrue((zsh_dir / ".zshrc").is_symlink())
        self.assertTrue((config_home / "fish/config.fish").is_symlink())

    def test_existing_local_and_pi_files_are_preserved(self):
        local = self.home / ".zsh_local"
        local.write_text("keep me\n")
        settings = self.home / ".pi/agent/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text('{"mine":true}\n')
        trust = self.home / ".pi/agent/trust.json"
        trust.symlink_to(self.root / "dangling trust")

        self.run_helper()
        self.assertEqual(local.read_text(), "keep me\n")
        self.assertEqual(settings.read_text(), '{"mine":true}\n')
        self.assertTrue(trust.is_symlink())
        self.assertEqual(os.readlink(trust), str(self.root / "dangling trust"))
        self.assertTrue((self.home / ".fish_local").is_file())

    def test_directory_target_is_refused_before_any_change(self):
        original = self.home / ".zshrc"
        original.write_bytes(b"keep unchanged\n")
        config_home = self.home / "config"
        (config_home / "zellij/config.kdl").mkdir(parents=True)

        result = self.run_helper(
            env={"XDG_CONFIG_HOME": str(config_home)},
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to replace directory", result.stderr)
        self.assertEqual(original.read_bytes(), b"keep unchanged\n")
        self.assertFalse((self.home / ".zshenv").exists())
        self.assertFalse((self.home / ".local/state/dotfiles").exists())

    def test_destination_directory_symlink_into_checkout_is_refused(self):
        config_link = self.home / "config-link"
        config_link.symlink_to(ROOT / ".config", target_is_directory=True)
        result = self.run_helper(
            env={"XDG_CONFIG_HOME": str(config_link)},
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("resolves inside the checkout", result.stderr)
        self.assertFalse((self.home / ".zshrc").exists())

    def test_fifo_target_is_refused_before_any_change(self):
        original = self.home / ".zshrc"
        original.write_bytes(b"unchanged\n")
        os.mkfifo(self.home / ".vimrc")
        result = self.run_helper(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to replace non-file", result.stderr)
        self.assertEqual(original.read_bytes(), b"unchanged\n")
        self.assertFalse((self.home / ".zshenv").exists())

    def test_failed_restoration_keeps_the_original_backup(self):
        original = self.home.resolve() / ".zshrc"
        original.write_bytes(b"irreplaceable configuration\n")
        original.chmod(0o640)
        shim_dir = self.root / "restore failure"
        shim_dir.mkdir()
        real_mv = shutil.which("mv")
        (shim_dir / "mv").write_text(
            "#!/bin/sh\n"
            'case "$1" in */originals/*) exit 75;; esac\n'
            f"exec {shlex.quote(real_mv)} \"$@\"\n"
        )
        (shim_dir / "ln").write_text("#!/bin/sh\nexit 76\n")
        (shim_dir / "mv").chmod(0o755)
        (shim_dir / "ln").chmod(0o755)
        result = self.run_helper(
            env={"PATH": str(shim_dir) + os.pathsep + self.env["PATH"]},
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("backups retained at", result.stderr)
        backups = list((self.home / ".local/state/dotfiles").glob("dotfiles-setup-*"))
        self.assertEqual(len(backups), 1)
        preserved = backups[0].resolve() / "originals" / str(original).lstrip("/")
        self.assertEqual(preserved.read_bytes(), b"irreplaceable configuration\n")
        manifest = (backups[0] / "manifest.tsv").read_text()
        self.assertIn(f"{original}\t{preserved}\t640\n", manifest)

    def test_ai_instruction_links_replace_existing_files_with_backup(self):
        claude = self.home / ".claude/CLAUDE.md"
        claude.parent.mkdir()
        claude.write_bytes(b"old claude\n")
        local = self.home / ".config/ai/AGENTS.local.md"
        local.parent.mkdir(parents=True)
        local.write_bytes(b"local rules\n")

        result = self.run_helper("--zsh-only")
        self.assertIn("Backups stored under", result.stdout)
        generated = self.home / ".config/ai/AGENTS.md"
        self.assertEqual(
            generated.read_bytes(),
            (ROOT / "ai/AGENTS.md").read_bytes() + b"\nlocal rules\n",
        )
        self.assertTrue(claude.is_symlink())
        self.assertEqual(os.readlink(claude), str(generated.resolve()))
        self.assertTrue((self.home / ".codex/AGENTS.md").is_symlink())
        backup_dir = Path(result.stdout.split("Backups stored under ", 1)[1].strip())
        preserved = backup_dir / "originals" / str(self.home.resolve() / ".claude/CLAUDE.md").lstrip("/")
        self.assertEqual(preserved.read_bytes(), b"old claude\n")

    def test_gui_helper_links_without_cloning_themes(self):
        config_home = self.home / "config with spaces"
        self.run_helper("--gui", env={"XDG_CONFIG_HOME": str(config_home)})
        alacritty = config_home / "alacritty/alacritty.toml"
        self.assertTrue(alacritty.is_symlink())
        self.assertEqual(os.readlink(alacritty), str(ROOT / ".config/alacritty/alacritty.toml"))
        self.assertFalse((config_home / "alacritty/themes").exists())

    def test_setup_zsh_wrapper_installs_zsh_and_required_helpers(self):
        result = subprocess.run(
            [BASH, str(ROOT / "setup-zsh.sh")],
            cwd=ROOT,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in [".zshrc", ".zshenv", ".zprofile"]:
            self.assertTrue((self.home / name).is_symlink())
        for name in ["cargo-binstall-latest", "dotfiles-rust-update", "dotfiles-ai-build"]:
            self.assertTrue((self.home / ".local/bin" / name).is_symlink())
        self.assertFalse((self.home / ".config/fish/config.fish").exists())
        self.assertFalse((self.home / ".pi/agent/settings.json").exists())

    def test_link_failure_rolls_back_prior_links_and_original_modes(self):
        (self.home / ".zshrc").write_bytes(b"original\n")
        (self.home / ".zshrc").chmod(0o640)
        dangling = self.root / "dangling zshenv"
        (self.home / ".zshenv").symlink_to(dangling)
        shim_dir = self.root / "shim"
        shim_dir.mkdir()
        count_file = self.root / "ln-count"
        real_ln = shutil.which("ln")
        shim = shim_dir / "ln"
        shim.write_text(
            "#!/bin/sh\n"
            "count=0\n"
            "if [ -f \"$LN_COUNT_FILE\" ]; then count=$(cat \"$LN_COUNT_FILE\"); fi\n"
            "count=$((count + 1))\n"
            "printf '%s' \"$count\" > \"$LN_COUNT_FILE\"\n"
            "if [ \"$count\" -eq 2 ]; then exit 1; fi\n"
            f"exec {shlex.quote(real_ln)} \"$@\"\n"
        )
        shim.chmod(0o755)

        result = self.run_helper(
            env={
                "PATH": str(shim_dir) + os.pathsep + self.env["PATH"],
                "LN_COUNT_FILE": str(count_file),
            },
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / ".zshrc").read_bytes(), b"original\n")
        self.assertEqual(stat.S_IMODE((self.home / ".zshrc").stat().st_mode), 0o640)
        self.assertTrue((self.home / ".zshenv").is_symlink())
        self.assertEqual(os.readlink(self.home / ".zshenv"), str(dangling))
        self.assertFalse((self.home / ".zprofile").exists())
        self.assertFalse((self.home / ".local/state/dotfiles").exists())

    def test_term_signal_rolls_back_completed_link(self):
        (self.home / ".zshrc").write_bytes(b"original before signal\n")
        shim_dir = self.root / "signal shim"
        shim_dir.mkdir()
        ready = self.root / "ln-ready"
        release = self.root / "ln-release"
        real_ln = shutil.which("ln")
        shim = shim_dir / "ln"
        shim.write_text(
            "#!/bin/sh\n"
            f"printf ready > {shlex.quote(str(ready))}\n"
            f"while [ ! -e {shlex.quote(str(release))} ]; do sleep 0.02; done\n"
            f"exec {shlex.quote(real_ln)} \"$@\"\n"
        )
        shim.chmod(0o755)
        run_env = self.env.copy()
        run_env["PATH"] = str(shim_dir) + os.pathsep + self.env["PATH"]
        process = subprocess.Popen(
            [BASH, str(ROOT / "setup-config.sh")],
            cwd=ROOT,
            env=run_env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline and not ready.exists() and process.poll() is None:
            time.sleep(0.02)
        self.assertTrue(ready.exists())
        process.send_signal(signal.SIGTERM)
        release.touch()
        stdout, stderr = process.communicate(timeout=10)
        self.assertNotEqual(process.returncode, 0, stdout + stderr)
        self.assertEqual((self.home / ".zshrc").read_bytes(), b"original before signal\n")
        self.assertFalse((self.home / ".zshenv").exists())

if __name__ == "__main__":
    unittest.main()
