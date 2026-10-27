import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "bin" / "rustup-report"


class RustupReportTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.rustup_home = self.root / ".rustup"
        self.toolchain_dir = self.rustup_home / "toolchains"
        self.toolchain_dir.mkdir(parents=True)
        self.mock_bin = self.root / "bin"
        self.mock_bin.mkdir()
        rustup = self.mock_bin / "rustup"
        rustup.write_text(
            "#!/bin/sh\n"
            'if [ "$1" != "toolchain" ] || [ "$2" != "list" ]; then exit 2; fi\n'
            'if [ "${RUSTUP_STATUS_EXIT:-0}" -ne 0 ]; then exit "$RUSTUP_STATUS_EXIT"; fi\n'
            'printf "%s\\n" "${RUSTUP_LIST:-}"\n'
        )
        rustup.chmod(0o755)

    def tearDown(self):
        self.temp_dir.cleanup()

    def _add_toolchain(self, name):
        directory = self.toolchain_dir / name
        directory.mkdir()
        (directory / "payload").write_text(name)

    def _run(self, toolchains=(), status="", status_exit=0):
        for name in toolchains:
            self._add_toolchain(name)
        env = os.environ.copy()
        env.update(
            {
                "RUSTUP_HOME": str(self.rustup_home),
                "RUSTUP_LIST": status,
                "RUSTUP_STATUS_EXIT": str(status_exit),
                "PATH": os.pathsep.join([str(self.mock_bin), "/usr/bin", "/bin"]),
            }
        )
        return subprocess.run(
            ["bash", str(REPORT)],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_single_numbered_active_toolchain_is_not_a_review_candidate(self):
        toolchain = "1.98.1-aarch64-apple-darwin"
        result = self._run([toolchain], f"{toolchain} (active)")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Installed Rust toolchains: 1 (", result.stdout)
        self.assertIn(toolchain, result.stdout)
        self.assertIn("(active)", result.stdout)
        self.assertIn("Additional toolchains for manual review: none.", result.stdout)
        self.assertNotIn("Cleanup recommended", result.stdout)

    def test_stable_default_and_numbered_active_are_excluded(self):
        stable = "stable-aarch64-apple-darwin"
        numbered = "1.98.1-aarch64-apple-darwin"
        nightly = "nightly-aarch64-apple-darwin"
        status = f"{stable} (default)\n{numbered} (active)\n{nightly}"
        result = self._run([stable, numbered, nightly], status)

        self.assertEqual(result.returncode, 0, result.stderr)
        review_section = result.stdout.split("Additional toolchains for manual review:", 1)[1]
        self.assertIn(nightly, review_section)
        self.assertNotIn(stable, review_section)
        self.assertNotIn(numbered, review_section)
        self.assertIn("Project toolchain pins cannot be inferred", result.stdout)

    def test_older_numbered_and_nightly_toolchains_are_manual_review_candidates(self):
        stable = "stable-x86_64-unknown-linux-gnu"
        active = "1.97.0-x86_64-unknown-linux-gnu"
        default = "beta-x86_64-unknown-linux-gnu"
        numbered = "1.92.0-x86_64-unknown-linux-gnu"
        nightly = "nightly-2025-04-10-x86_64-unknown-linux-gnu"
        status = f"{stable} (default)\n{active} (active)\n{default} (default)\n{numbered}\n{nightly}"
        result = self._run([stable, active, default, numbered, nightly], status)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Additional toolchains for manual review: 2 (", result.stdout)
        review_section = result.stdout.split("Additional toolchains for manual review:", 1)[1]
        self.assertIn(numbered, review_section)
        self.assertIn(nightly, review_section)
        self.assertNotIn(stable, review_section)
        self.assertNotIn(active, review_section)
        self.assertNotIn(default, review_section)

    def test_empty_inventory(self):
        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "No Rust toolchains installed.\n")

    def test_status_failure_preserves_inventory_without_recommending_removal(self):
        stable = "stable-x86_64-unknown-linux-gnu"
        nightly = "nightly-x86_64-unknown-linux-gnu"
        result = self._run([stable, nightly], status_exit=1)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Installed Rust toolchains: 2 (", result.stdout)
        self.assertIn(stable, result.stdout)
        self.assertIn(nightly, result.stdout)
        self.assertIn("Toolchain status unavailable", result.stdout)
        self.assertIn("no review candidates are listed", result.stdout)
        self.assertNotIn("safe to remove", result.stdout)
        self.assertNotIn("Cleanup recommended", result.stdout)


if __name__ == "__main__":
    unittest.main()
