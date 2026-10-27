import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "bin" / "dotfiles-ai-build"
BASH = shutil.which("bash")


class AiBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.config = self.root / "config"
        self.home.mkdir()
        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home)
        self.env["XDG_CONFIG_HOME"] = str(self.config)
        self.env.pop("DOTFILES_DIR", None)
        self.output = self.config / "ai" / "AGENTS.md"
        self.local = self.config / "ai" / "AGENTS.local.md"
        self.generic = (ROOT / "ai" / "AGENTS.md").read_bytes()

    def tearDown(self):
        for path in (self.config / "ai").glob("*"):
            path.chmod(0o600)
        self.temp.cleanup()

    def build(self, script=BUILD, env=None, check=True, args=()):
        run_env = self.env.copy()
        if env:
            run_env.update(env)
        result = subprocess.run(
            [BASH, str(script), *args],
            env=run_env,
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        if check and result.returncode != 0:
            self.fail(result.stdout + result.stderr)
        return result

    def write_local(self, content):
        self.local.parent.mkdir(parents=True, exist_ok=True)
        self.local.write_bytes(content)

    def test_without_local_file_output_is_generic_bytes(self):
        self.build()
        self.assertEqual(self.output.read_bytes(), self.generic)

    def test_empty_local_file_is_ignored(self):
        self.write_local(b"")
        self.build()
        self.assertEqual(self.output.read_bytes(), self.generic)

    def test_local_file_is_appended_after_single_newline(self):
        self.write_local(b"local rules\nno trailing newline")
        self.build()
        self.assertEqual(self.output.read_bytes(), self.generic + b"\nlocal rules\nno trailing newline")

    def test_output_is_read_only_and_rebuild_replaces_it(self):
        self.build()
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o444)
        self.write_local(b"later\n")
        self.build()
        self.assertEqual(self.output.read_bytes(), self.generic + b"\nlater\n")
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o444)
        self.assertEqual(sorted(p.name for p in self.output.parent.iterdir()), ["AGENTS.local.md", "AGENTS.md"])

    def test_output_override_writes_to_custom_file(self):
        output = self.root / "custom" / "AGENTS.md"
        self.build(args=("--output", str(output)))
        self.assertEqual(output.read_bytes(), self.generic)
        self.assertFalse(self.output.exists())
        output.chmod(0o600)

    def test_missing_generic_file_fails_without_output(self):
        fixture = self.root / "fixture"
        (fixture / "bin").mkdir(parents=True)
        shutil.copy2(BUILD, fixture / "bin" / BUILD.name)
        result = self.build(fixture / "bin" / BUILD.name, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("generic AI instructions are missing", result.stderr)
        self.assertFalse(self.output.exists())

    def test_symlinked_invocation_finds_repository(self):
        link = self.root / "local bin" / "dotfiles-ai-build"
        link.parent.mkdir()
        link.symlink_to(BUILD)
        self.build(link)
        self.assertEqual(self.output.read_bytes(), self.generic)

    def test_dotfiles_dir_override(self):
        fixture = self.root / "fixture"
        (fixture / "ai").mkdir(parents=True)
        (fixture / "ai" / "AGENTS.md").write_bytes(b"custom\n")
        self.build(env={"DOTFILES_DIR": str(fixture)})
        self.assertEqual(self.output.read_bytes(), b"custom\n")


if __name__ == "__main__":
    unittest.main()
