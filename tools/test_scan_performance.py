import unittest

from analyze_scan_performance import summarize


def trials(count=100):
    return [{"id": f"wide-{index:03}", "durationMS": 10_000, "outcome": "complete", "countsMatch": True,
             "coverageGaps": 0, "providerReads": 0, "sourceClass": "local_internal", "longestHeartbeatMS": 55}
            for index in range(count)]


class PerformanceReportTests(unittest.TestCase):
    def test_missing_cohort_or_extra_trial_fails_inventory_check(self):
        rows = trials()
        expected = [row["id"] for row in rows] + ["deep-000"]
        with self.assertRaises(ValueError):
            summarize(rows, expected_ids=expected)
        with self.assertRaises(ValueError):
            summarize(rows, expected_ids=[row["id"] for row in rows[:-1]])

    def test_cannot_lower_sample_floor(self):
        with self.assertRaises(ValueError):
            summarize(trials(3), expected_per_cohort=3)

    def test_does_not_claim_p99_from_a_small_sample(self):
        report = summarize(trials(3))["wide"]
        self.assertIsNone(report["empiricalP99MS"])
        self.assertFalse(report["goalMetForThisCohort"])

    def test_keeps_over_goal_samples_and_uses_nearest_rank(self):
        rows = trials()
        rows[-1]["durationMS"] = 240_000
        rows[-2]["durationMS"] = 130_000
        report = summarize(rows)["wide"]
        self.assertEqual(report["empiricalP99MS"], 130_000)
        self.assertEqual(report["over120Seconds"], 2)
        self.assertFalse(report["goalMetForThisCohort"])

    def test_partial_cloud_and_failed_trials_cannot_pass_local_goal(self):
        for key, value in (("coverageGaps", 1), ("providerReads", 1), ("outcome", "harness_deadline"), ("countsMatch", False)):
            with self.subTest(key=key):
                rows = trials()
                rows[-1][key] = value
                self.assertFalse(summarize(rows)["wide"]["goalMetForThisCohort"])


if __name__ == "__main__":
    unittest.main()
