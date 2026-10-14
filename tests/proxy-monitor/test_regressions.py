import pathlib, re, unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'openwrt/proxy-monitor/install-proxy-monitor-v15.sh').read_text()

def payload(marker):
    return SOURCE.split("<<'" + marker + "'\n", 1)[1].split('\n' + marker, 1)[0]

class RegressionTests(unittest.TestCase):
    def test_badges_remain_dom_nodes(self):
        self.assertNotIn('String(value)', payload('LUCIJS'))

    def test_mobile_is_migrated_before_collector_removal(self):
        self.assertIn('JSONMOBILE', SOURCE)
        self.assertIn('mobile-token', SOURCE)

    def test_installer_uses_unique_private_backups(self):
        self.assertIn('mktemp -d', SOURCE)
        self.assertIn('umask 077', SOURCE)

    def test_unknown_backend_is_not_fabricated_failure(self):
        self.assertIn('typeof value', payload('LUCIJS'))
        self.assertIn('UNKNOWN', payload('LUCIJS'))

    def test_correct_native_theme_tokens(self):
        self.assertIn('--border-color-medium', payload('LUCIJS'))
        self.assertNotIn('--background-color,', payload('LUCIJS'))

if __name__ == '__main__':
    unittest.main()
