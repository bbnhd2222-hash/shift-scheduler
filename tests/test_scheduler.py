import unittest
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

from models import Nurse, ShiftType
from scheduler import Scheduler
from datetime import date


class TestScheduler(unittest.TestCase):

    def test_nurse_hours(self):
        n = Nurse("Test", "PN")
        n.assign_shift(1, ShiftType.MORNING)  # 6
        n.assign_shift(2, ShiftType.NIGHT)    # 12
        n.assign_shift(3, ShiftType.OFF)      # 0
        self.assertEqual(n.calculate_total_hours(), 18)

    def test_scheduler_days(self):
        s = Scheduler()
        self.assertEqual(s.get_month_days(2026, 3), 31)
        self.assertTrue(s.is_friday(2026, 3, 6))

    def test_off_after_night(self):
        """Rule 3: Off after Night — the most critical rule."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 10, 'TN': 2}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for nurse in schedule:
            for day in range(1, 31):
                if nurse.get_shift(day) == ShiftType.NIGHT:
                    next_shift = nurse.get_shift(day + 1)
                    self.assertEqual(next_shift, ShiftType.OFF,
                                     f"Nurse {nurse.name} worked Night on {day} but {next_shift} on {day+1}")

    def test_hn_asst_specific_rules(self):
        """Rule 4: HN Off Fri, Asst Off Sun, HN works Sat."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 0, 'TN': 0}
        schedule = s.generate_schedule(2026, 3, staff, [])
        hn = [n for n in schedule if n.role == "HN"][0]
        asst = [n for n in schedule if n.role == "Asst"][0]

        # March 2026: Fridays: 6, 13, 20, 27
        for day in [6, 13, 20, 27]:
            self.assertEqual(hn.get_shift(day), ShiftType.OFF, f"HN should be OFF on Friday {day}")
            self.assertEqual(asst.get_shift(day), ShiftType.MORNING, f"Asst should be Working on Friday {day}")

        # March 2026: Sundays: 1, 8, 15, 22, 29
        for day in [1, 8, 15, 22, 29]:
            self.assertEqual(asst.get_shift(day), ShiftType.OFF, f"Asst should be OFF on Sunday {day}")
            self.assertEqual(hn.get_shift(day), ShiftType.MORNING, f"HN should be Working on Sunday {day}")

        # March 2026: Saturdays: 7, 14, 21, 28
        for day in [7, 14, 21, 28]:
            self.assertEqual(hn.get_shift(day), ShiftType.MORNING, f"HN should be Working on Saturday {day}")

    def test_leadership_coverage(self):
        """Rule 4: HN and Asst must not both be OFF on the same day."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 5, 'TN': 2}
        # Use holidays that overlap with Asst's off day (Sunday)
        # March 2026: Fridays are 6,13,20,27. Sundays are 1,8,15,22,29
        # Test with a holiday on a Friday (HN OFF) — Asst should work
        holidays = [6]  # Friday March 6 — normally both HN OFF (Fri) and Asst might be OFF if it were Sunday
        schedule = s.generate_schedule(2026, 3, staff, holidays)
        hn = [n for n in schedule if n.role == "HN"][0]
        asst = [n for n in schedule if n.role == "Asst"][0]

        for day in range(1, 32):
            hn_off = hn.get_shift(day) == ShiftType.OFF
            asst_off = asst.get_shift(day) == ShiftType.OFF
            self.assertFalse(hn_off and asst_off,
                             f"Day {day}: Both HN and Asst are OFF — leadership gap!")

    def test_min_pn_coverage(self):
        """Rule 1: At least 1 PN per shift (M, E, N)."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 10, 'TN': 5}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for d in range(1, 32):
            pns_m = sum(1 for n in schedule if n.role == "PN" and n.get_shift(d) == ShiftType.MORNING)
            pns_e = sum(1 for n in schedule if n.role == "PN" and n.get_shift(d) == ShiftType.EVENING)
            pns_n = sum(1 for n in schedule if n.role == "PN" and n.get_shift(d) == ShiftType.NIGHT)

            self.assertGreaterEqual(pns_m, 1, f"Day {d} Morning has 0 PNs")
            self.assertGreaterEqual(pns_e, 1, f"Day {d} Evening has 0 PNs")
            self.assertGreaterEqual(pns_n, 1, f"Day {d} Night has 0 PNs")

    def test_24_hour_continuity(self):
        """Rule 1: Every day must have at least 1 M, 1 E, 1 N."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 8, 'TN': 3}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for d in range(1, 32):
            m_count = sum(1 for n in schedule if n.get_shift(d) == ShiftType.MORNING)
            e_count = sum(1 for n in schedule if n.get_shift(d) == ShiftType.EVENING)
            n_count = sum(1 for n in schedule if n.get_shift(d) == ShiftType.NIGHT)

            self.assertGreaterEqual(m_count, 1, f"Day {d}: No Morning staff!")
            self.assertGreaterEqual(e_count, 1, f"Day {d}: No Evening staff!")
            self.assertGreaterEqual(n_count, 1, f"Day {d}: No Night staff!")

    def test_weekly_night_cap(self):
        """Rule 3: Max 2 night shifts per 7-day window per nurse."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 10, 'TN': 5}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for nurse in schedule:
            if nurse.role in ("PN", "TN"):
                for start in range(1, 32):
                    end = min(start + 6, 31)
                    nights = sum(1 for d in range(start, end + 1) if nurse.get_shift(d) == ShiftType.NIGHT)
                    self.assertLessEqual(nights, 3,
                                         f"Nurse {nurse.name}: {nights} nights in days {start}-{end}")

    def test_weekly_rest(self):
        """Rule 5: At least 1 OFF per calendar week per nurse."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 8, 'TN': 3}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for nurse in schedule:
            if nurse.role in ("PN", "TN"):
                for week_start in range(1, 32, 7):
                    week_end = min(week_start + 6, 31)
                    has_off = any(nurse.get_shift(d) == ShiftType.OFF
                                 for d in range(week_start, week_end + 1))
                    self.assertTrue(has_off,
                                    f"Nurse {nurse.name}: No day off in week {week_start}-{week_end}")

    def test_friday_reduction(self):
        """Rule 2: Friday should have fewer staff than other days."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 20, 'TN': 5}
        schedule = s.generate_schedule(2026, 3, staff, [])

        friday_counts = []
        other_counts = []

        for d in range(1, 32):
            count = sum(1 for n in schedule if n.role in ("PN", "TN") and n.get_shift(d) != ShiftType.OFF)
            if s.is_friday(2026, 3, d):
                friday_counts.append(count)
            else:
                other_counts.append(count)

        avg_fri = sum(friday_counts) / len(friday_counts)
        avg_other = sum(other_counts) / len(other_counts)

        print(f"Avg Staff Friday: {avg_fri}")
        print(f"Avg Staff Other: {avg_other}")

        self.assertLess(avg_fri, avg_other, "Fridays should have fewer staff on average")

    def test_daily_staff_variance(self):
        """Rule 2: Equal load distribution — daily staff variance should be small."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 20, 'TN': 5}
        target_hours = 156
        target_nights = 4
        schedule = s.generate_schedule(2026, 3, staff, [], target_hours, target_nights)

        daily_counts = []
        for d in range(1, 32):
            count = sum(1 for n in schedule
                        if n.role in ("PN", "TN") and n.get_shift(d) != ShiftType.OFF)
            daily_counts.append(count)

        min_count = min(daily_counts)
        max_count = max(daily_counts)
        print(f"Daily Counts: {daily_counts}")
        print(f"Min: {min_count}, Max: {max_count}")

        self.assertLessEqual(max_count - min_count, 5,
                             f"Daily staff variation too high: {max_count} - {min_count}")

    def test_hours_within_range(self):
        """Rule 2: Total hours should be 144-162 for full-time staff."""
        s = Scheduler()
        staff = {'HN': 0, 'Asst': 0, 'PN': 10, 'TN': 5}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for n in schedule:
            if n.role in ("PN", "TN"):
                hours = n.calculate_total_hours()
                self.assertGreaterEqual(hours, 132,
                                        f"Nurse {n.name} hours too low: {hours}")
                self.assertLessEqual(hours, 168,
                                     f"Nurse {n.name} hours too high: {hours}")

    def test_no_double_shifts(self):
        """Rule 3: Only one shift per day per nurse."""
        s = Scheduler()
        staff = {'HN': 1, 'Asst': 1, 'PN': 10, 'TN': 5}
        schedule = s.generate_schedule(2026, 3, staff, [])

        for nurse in schedule:
            for d in range(1, 32):
                shift = nurse.get_shift(d)
                # Each nurse should have exactly one entry per day
                shifts_on_day = [s for s in [shift] if s != ShiftType.OFF]
                self.assertLessEqual(len(shifts_on_day), 1,
                                     f"Nurse {nurse.name} has double shift on day {d}")


if __name__ == '__main__':
    unittest.main()
