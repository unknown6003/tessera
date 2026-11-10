import unittest

from validate_release import validate


class ReleasePolicyTests(unittest.TestCase):
    def test_supported_series_and_tag(self):
        validate("0.2.0", "12", "v0.2.0")

    def test_major_versions_cannot_use_an_environment_override(self):
        for version in ("1.0.0", "1.0.1", "2.0.0", "10.0.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                validate(version, "12")

    def test_malformed_identity_and_wrong_tag(self):
        for version, build, tag in (("0.02.0", "12", None), ("0.2.0", "0", None),
                                    ("0.2.0", "12", "v1.0.0")):
            with self.subTest(version=version, build=build, tag=tag), self.assertRaises(ValueError):
                validate(version, build, tag)


if __name__ == "__main__":
    unittest.main()
