import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class AlacrittyConfigTests(unittest.TestCase):
    def setUp(self):
        self.config = (ROOT / ".config/alacritty/alacritty.toml").read_text()

    def test_keeps_maximized_window_without_decorations(self):
        self.assertIn('startup_mode = "Maximized"', self.config)
        self.assertIn('decorations = "none"', self.config)
        self.assertNotIn('startup_mode = "Fullscreen"', self.config)
        self.assertNotIn('startup_mode = "SimpleFullscreen"', self.config)

    def test_keeps_theme_shell_and_font(self):
        self.assertIn('import = ["themes/themes/aura.toml"]', self.config)
        self.assertIn('program = "/bin/zsh"', self.config)
        self.assertIn('family = "CaskaydiaCove Nerd Font Mono"', self.config)


class ZellijConfigTests(unittest.TestCase):
    def setUp(self):
        self.config = (ROOT / ".config/zellij/config.kdl").read_text()

    def test_keeps_custom_keybinds_and_default_mode(self):
        self.assertIn("keybinds clear-defaults=true", self.config)
        self.assertIn('default_mode "locked"', self.config)

    def test_keeps_status_bar_and_session_manager_aliases(self):
        self.assertIn('status-bar location="zellij:status-bar"', self.config)
        self.assertIn('session-manager location="zellij:session-manager"', self.config)


if __name__ == "__main__":
    unittest.main()
