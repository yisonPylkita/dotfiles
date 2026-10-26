import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bin" / "dotfiles-rust-update"
CRATES = ["starship", "ripgrep", "lsd", "bat", "gitui", "zellij"]


class RustUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.home = self.root / "home"
        self.project = self.root / "project"
        self.project_bin = self.project / "bin"
        self.cargo_bin = self.home / ".cargo" / "bin"
        self.local_bin = self.home / ".local" / "bin"
        self.log = self.root / "calls.jsonl"
        self.home.mkdir(parents=True)
        self.project_bin.mkdir(parents=True)
        self.cargo_bin.mkdir(parents=True)
        self.local_bin.mkdir(parents=True)
        self.project.joinpath("Cargo.toml").write_text("[package]\nname = 'project'\n")
        self.project.joinpath("rust-toolchain.toml").write_text("[toolchain]\nchannel = 'project'\n")
        self.home.joinpath(".cargo").joinpath("config.toml").write_text(
            "[build]\ntarget-dir = 'global-target'\n"
        )
        self._write_mock(
            self.cargo_bin / "rustup",
            "rustup",
            "${*}",
            'exit "${RUSTUP_EXIT:-0}"',
        )
        self._write_mock(
            self.local_bin / "cargo-binstall-latest",
            "binstall",
            "${*}",
            'if [ "${FAIL_CRATE:-}" = "$2" ]; then exit 23; fi\nexit 0',
        )
        self._write_mock(self.project_bin / "rustup", "shadow-rustup", "${*}", "exit 0")
        self._write_mock(
            self.project_bin / "cargo-binstall-latest",
            "shadow-binstall",
            "${*}",
            "exit 0",
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def _write_mock(self, path, kind, arguments, exit_status):
        script = "\n".join(
            [
                "#!/bin/sh",
                '"$TEST_PYTHON" -c \'import json, os, sys; print(json.dumps({"kind": sys.argv[1], "cwd": os.getcwd(), "cargo_home": os.environ.get("CARGO_HOME"), "rustup_home": os.environ.get("RUSTUP_HOME"), "install_root": os.environ.get("CARGO_INSTALL_ROOT"), "toolchain": os.environ.get("RUSTUP_TOOLCHAIN", "<unset>"), "path": os.environ.get("PATH"), "args": sys.argv[2:]}))\' '
                + f"{kind} {arguments} >> \"$CALL_LOG\"",
                exit_status,
                "",
            ]
        )
        path.write_text(script)
        path.chmod(0o755)

    def _run(self, *arguments, **extra_env):
        path = os.pathsep.join(
            [
                str(self.project_bin),
                "/usr/bin",
                "/bin",
                "/usr/sbin",
                "/sbin",
            ]
        )
        env = {
            "HOME": str(self.home),
            "PATH": path,
            "CALL_LOG": str(self.log),
            "TEST_PYTHON": sys.executable,
            "CARGO_HOME": str(self.project / "cargo-home"),
            "RUSTUP_HOME": str(self.project / "rustup-home"),
            "CARGO_INSTALL_ROOT": str(self.project / "install-root"),
            "RUSTUP_TOOLCHAIN": "project-toolchain",
            **extra_env,
        }
        original_cwd = os.getcwd()
        original_env = os.environ.copy()
        result = subprocess.run(
            [str(HELPER), *arguments],
            cwd=self.project,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(os.getcwd(), original_cwd)
        self.assertEqual(os.environ, original_env)
        return result

    def _calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_default_updates_rustup_and_global_cli_tools(self):
        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self._calls()
        self.assertEqual([call["kind"] for call in calls], ["rustup"] + ["binstall"] * 6)
        self.assertEqual(calls[0]["args"], ["update"])
        self.assertEqual([call["args"] for call in calls[1:]], [["--force", crate] for crate in CRATES])
        for call in calls:
            self.assertEqual(call["cwd"], str(self.home.resolve()))
            self.assertEqual(call["cargo_home"], str(self.home / ".cargo"))
            self.assertEqual(call["rustup_home"], str(self.home / ".rustup"))
            self.assertEqual(call["install_root"], str(self.home / ".cargo"))
            self.assertEqual(call["toolchain"], "<unset>")
            self.assertTrue(call["path"].startswith(f"{self.cargo_bin}:{self.local_bin}:"))

    def test_tools_mode_skips_rustup(self):
        result = self._run("tools")

        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self._calls()
        self.assertEqual([call["kind"] for call in calls], ["binstall"] * 6)
        self.assertEqual([call["args"][1] for call in calls], CRATES)

    def test_stops_when_rustup_fails(self):
        result = self._run(RUSTUP_EXIT="17")

        self.assertEqual(result.returncode, 17)
        self.assertEqual([call["kind"] for call in self._calls()], ["rustup"])

    def test_stops_when_a_cli_update_fails(self):
        result = self._run("tools", FAIL_CRATE="ripgrep")

        self.assertEqual(result.returncode, 23)
        self.assertEqual(
            [call["args"][1] for call in self._calls()], ["starship", "ripgrep"]
        )


class ShellSyntaxTests(unittest.TestCase):
    def test_bash_helper_syntax(self):
        result = subprocess.run(
            ["bash", "-n", str(HELPER)], capture_output=True, text=True, check=False
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("fish"), "fish is unavailable")
    def test_fish_config_syntax(self):
        result = subprocess.run(
            ["fish", "-n", str(ROOT / ".config" / "fish" / "config.fish")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("fish"), "fish is unavailable")
    def test_noninteractive_fish_adds_cargo_path_without_env_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            (home / ".cargo" / "bin").mkdir(parents=True)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["CONFIG_FILE"] = str(ROOT / ".config" / "fish" / "config.fish")
            result = subprocess.run(
                [
                    "fish",
                    "--no-config",
                    "-c",
                    'source $CONFIG_FILE; contains -- "$HOME/.cargo/bin" $PATH; or exit 1; if set -q fish_user_paths; and contains -- "$HOME/.cargo/bin" $fish_user_paths; exit 2; end',
                ],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is unavailable")
    def test_zsh_config_syntax(self):
        for filename in (".zshenv", ".zprofile", ".zshrc"):
            result = subprocess.run(
                ["zsh", "-n", str(ROOT / filename)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, f"{filename}: {result.stderr}")


if __name__ == "__main__":
    unittest.main()
