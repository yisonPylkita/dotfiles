import contextlib
import importlib.machinery
import importlib.util
import io
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bin" / "cargo-binstall-latest"
LOADER = importlib.machinery.SourceFileLoader("cargo_binstall_latest", str(HELPER))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CargoBinstallLatestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def _executable(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("binary")
        path.chmod(0o755)
        return path

    def _main(self, arguments, which, run_side_effect):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with (
            patch.object(MODULE, "discover", return_value=("14.1.0", "aarch64-apple-darwin", "quickinstall")),
            patch.object(MODULE.shutil, "which", side_effect=which) as which_mock,
            patch.object(MODULE.subprocess, "run", side_effect=run_side_effect) as run_mock,
            patch.object(sys, "argv", [str(HELPER), *arguments]),
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            result = MODULE.main()
        return result, stdout.getvalue(), stderr.getvalue(), which_mock, run_mock

    def test_homebrew_binary_wins_and_direct_command_keeps_prebuilt_options(self):
        old_binary = self._executable(self.root / "home/.cargo/bin/cargo-binstall")
        formula_binary = self._executable(
            self.root / "brew/opt/cargo-binstall/bin/cargo-binstall"
        )
        target = "aarch64-apple-darwin"
        result, stdout, stderr, which, run = self._main(
            ["ripgrep", "--target", target, "--force"],
            lambda name: {
                "brew": "/mock/bin/brew",
                "cargo-binstall": str(old_binary),
            }.get(name),
            [
                types.SimpleNamespace(returncode=0, stdout=f"{formula_binary.parent.parent}\n"),
                types.SimpleNamespace(returncode=0),
            ],
        )

        self.assertEqual(result, 0, stderr)
        self.assertEqual(stdout, f"ripgrep\t14.1.0\t{target}\tquickinstall\n")
        self.assertEqual(
            run.call_args_list[0].args[0],
            ["/mock/bin/brew", "--prefix", "cargo-binstall"],
        )
        self.assertEqual(
            run.call_args_list[1].args[0],
            [
                str(formula_binary),
                "--no-confirm",
                "--disable-strategies",
                "compile",
                "--targets",
                target,
                "--force",
                "ripgrep@=14.1.0",
            ],
        )
        self.assertNotIn(str(old_binary), run.call_args_list[1].args[0])
        self.assertEqual(which.call_args_list[0].args, ("brew",))

    def test_falls_back_when_homebrew_is_absent(self):
        binary = self._executable(self.root / "cargo/bin/cargo-binstall")
        result, _, stderr, _, run = self._main(
            ["ripgrep"],
            lambda name: str(binary) if name == "cargo-binstall" else None,
            [types.SimpleNamespace(returncode=0)],
        )

        self.assertEqual(result, 0, stderr)
        self.assertEqual(run.call_args.args[0][0], str(binary))
        self.assertEqual(run.call_count, 1)

    def test_falls_back_when_homebrew_formula_is_missing(self):
        binary = self._executable(self.root / "cargo/bin/cargo-binstall")
        result, _, stderr, _, run = self._main(
            ["ripgrep"],
            lambda name: {
                "brew": "/mock/bin/brew",
                "cargo-binstall": str(binary),
            }.get(name),
            [
                types.SimpleNamespace(returncode=1, stdout=""),
                types.SimpleNamespace(returncode=0),
            ],
        )

        self.assertEqual(result, 0, stderr)
        self.assertEqual(run.call_args_list[1].args[0][0], str(binary))

    def test_falls_back_when_homebrew_binary_is_not_executable(self):
        binary = self._executable(self.root / "cargo/bin/cargo-binstall")
        invalid = self.root / "brew/opt/cargo-binstall/bin/cargo-binstall"
        invalid.parent.mkdir(parents=True)
        invalid.write_text("not executable")
        invalid.chmod(0o644)
        result, _, stderr, _, run = self._main(
            ["ripgrep"],
            lambda name: {
                "brew": "/mock/bin/brew",
                "cargo-binstall": str(binary),
            }.get(name),
            [
                types.SimpleNamespace(returncode=0, stdout=f"{invalid.parent.parent}\n"),
                types.SimpleNamespace(returncode=0),
            ],
        )

        self.assertEqual(result, 0, stderr)
        self.assertEqual(run.call_args_list[1].args[0][0], str(binary))

    def test_reports_missing_installer_without_attempting_install(self):
        result, _, stderr, _, run = self._main(
            ["ripgrep"], lambda name: None, []
        )

        self.assertEqual(result, 1)
        self.assertIn("cargo-binstall executable not found", stderr)
        self.assertIn("install it with Homebrew or add it to PATH", stderr)
        run.assert_not_called()

    def test_check_does_not_resolve_or_run_installer(self):
        result, stdout, stderr, which, run = self._main(
            ["ripgrep", "--check"],
            lambda name: self.fail(f"unexpected executable lookup: {name}"),
            [],
        )

        self.assertEqual(result, 0, stderr)
        self.assertEqual(stdout, "ripgrep\t14.1.0\taarch64-apple-darwin\tquickinstall\n")
        which.assert_not_called()
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
