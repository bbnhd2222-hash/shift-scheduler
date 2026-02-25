import calendar
import math
import random
from datetime import date
from typing import List, Dict, Any
from models import Nurse, ShiftType

class Scheduler:
    def __init__(self):
        pass

    def get_month_days(self, year: int, month: int) -> int:
        return calendar.monthrange(year, month)[1]

    def is_friday(self, year: int, month: int, day: int) -> bool:
        return date(year, month, day).weekday() == 4

    def is_saturday(self, year: int, month: int, day: int) -> bool:
        return date(year, month, day).weekday() == 5

    # ---------- helpers for weekly checks ----------
    @staticmethod
    def _nights_in_window(nurse: 'Nurse', center_day: int, window: int = 7) -> int:
        """Count night shifts in a 7-day window ending on center_day."""
        count = 0
        for d in range(max(1, center_day - window + 1), center_day + 1):
            if nurse.get_shift(d) == ShiftType.NIGHT:
                count += 1
        return count

    @staticmethod
    def _has_off_in_week(nurse: 'Nurse', week_start: int, week_end: int) -> bool:
        """Check nurse has at least 1 OFF in [week_start, week_end]."""
        for d in range(week_start, week_end + 1):
            if nurse.get_shift(d) == ShiftType.OFF:
                return True
        return False

    def generate_schedule(self, year: int, month: int, staff_config: Dict[str, int],
                          holidays: List[int], target_hours: int = 160,
                          target_nights: int = 4) -> List[Nurse]:
        nurses = []
        # Create staff in hierarchy order
        for i in range(staff_config.get('HN', 0)):
            nurses.append(Nurse(f"HN {i+1}", "HN"))
        for i in range(staff_config.get('Asst', 0)):
            nurses.append(Nurse(f"Asst {i+1}", "Asst"))
        for i in range(staff_config.get('PN', 0)):
            nurses.append(Nurse(f"PN {i+1}", "PN"))
        for i in range(staff_config.get('TN', 0)):
            nurses.append(Nurse(f"TN {i+1}", "TN"))

        days_in_month = self.get_month_days(year, month)
        days = range(1, days_in_month + 1)

        hns = [n for n in nurses if n.role == "HN"]
        assts = [n for n in nurses if n.role == "Asst"]
        pool = [n for n in nurses if n.role in ("PN", "TN")]

        # ========================================================
        # STEP 1: Head Nurse & Assistant Schedule
        # Rule 4: Morning-dominant. HN Off Fri, Asst Off Sun.
        # FIX #1: Never both OFF on same day (leadership coverage).
        # FIX: HN must be present on Saturdays.
        # ========================================================
        for hn in hns:
            for d in days:
                is_fri = self.is_friday(year, month, d)
                if is_fri:
                    hn.assign_shift(d, ShiftType.OFF)
                elif d in holidays:
                    hn.assign_shift(d, ShiftType.OFF)
                else:
                    hn.assign_shift(d, ShiftType.MORNING)

        for asst in assts:
            for d in days:
                weekday = date(year, month, d).weekday()
                is_sun = (weekday == 6)

                if is_sun:
                    asst.assign_shift(d, ShiftType.OFF)
                elif d in holidays:
                    asst.assign_shift(d, ShiftType.OFF)
                else:
                    asst.assign_shift(d, ShiftType.MORNING)

        # FIX #1: Leadership Coverage — if both OFF on same day, one must work
        for d in days:
            all_hn_off = all(hn.get_shift(d) == ShiftType.OFF for hn in hns) if hns else True
            all_asst_off = all(a.get_shift(d) == ShiftType.OFF for a in assts) if assts else True

            if hns and assts and all_hn_off and all_asst_off:
                # Force the Assistant to work (HN has seniority for day off)
                for a in assts:
                    a.assign_shift(d, ShiftType.MORNING)

        # FIX: HN Saturday Presence — HN should not be OFF on Saturday
        for hn in hns:
            for d in days:
                if self.is_saturday(year, month, d) and d not in holidays:
                    if hn.get_shift(d) == ShiftType.OFF:
                        hn.assign_shift(d, ShiftType.MORNING)

        # ========================================================
        # STEP 2: General Pool (PN/TN) — Supply-Driven
        # ========================================================
        total_pool = len(pool)
        days_count = len(days)

        if total_pool > 0:
            # --- Supply Calculation ---
            quantized_target = (target_hours // 6) * 6

            total_night_slots = total_pool * target_nights
            hours_spent_on_nights = total_night_slots * 12
            initial_remaining_hours = (total_pool * quantized_target) - hours_spent_on_nights
            initial_day_shifts = int(initial_remaining_hours / 6)
            initial_total_shifts = total_night_slots + initial_day_shifts

            # Holiday impact estimation
            avg_daily_shifts = math.ceil(initial_total_shifts / days_count)
            holiday_shifts_est = int(avg_daily_shifts * len(holidays))
            hours_lost_to_holidays = (holiday_shifts_est * 6) + 12  # small friction buffer

            remaining_hours_total = initial_remaining_hours - hours_lost_to_holidays
            total_day_shifts = int(remaining_hours_total / 6)
            total_shifts_needed = total_night_slots + total_day_shifts

            # Friday Reduction
            count_fridays = sum(1 for d in days if self.is_friday(year, month, d))
            count_others = days_count - count_fridays
            X_gap = 2

            avg_target_other = (total_shifts_needed + (X_gap * count_fridays)) / days_count
            base_other = int(avg_target_other)
            base_friday = base_other - X_gap

            guaranteed = (base_other * count_others) + (base_friday * count_fridays)
            extras = total_shifts_needed - guaranteed

            base_n = total_night_slots // days_count
            extra_n = total_night_slots % days_count

            ratio_m = 47 / 82
        else:
            base_other = base_friday = 0
            extras = 0
            base_n = extra_n = 0
            ratio_m = 0.5
            count_fridays = 0

        # Distribute targets per day
        schedule_targets = {}
        for d in days:
            if self.is_friday(year, month, d):
                schedule_targets[d] = base_friday
            else:
                schedule_targets[d] = base_other

        day_indices = list(range(1, days_count + 1))
        for i in range(extras):
            d = day_indices[i % days_count]
            schedule_targets[d] += 1

        night_targets = {d: base_n for d in days}
        for i in range(extra_n):
            d = day_indices[i % days_count]
            night_targets[d] += 1

        # ========================================================
        # Helper functions (closures over target_hours etc.)
        # ========================================================
        def get_effective_target_hours(n: Nurse) -> int:
            """FIX #7: Holiday exception — nurses who work holidays get reduced target."""
            h_shifts = n.count_holiday_shifts(holidays)
            return target_hours - (h_shifts * 6)

        def needs_night(n: Nurse) -> bool:
            return n.count_shift_type(ShiftType.NIGHT) < target_nights

        def needs_hours(n: Nurse) -> bool:
            return n.calculate_total_hours() < get_effective_target_hours(n)

        def can_take_shift(n: Nurse, shift_type: ShiftType) -> bool:
            eff_target = get_effective_target_hours(n)

            # Priority: Meet Target Nights
            if shift_type == ShiftType.NIGHT and needs_night(n):
                return True

            # STRICT check: Cannot exceed effective target
            current_total = n.calculate_total_hours()
            if current_total + shift_type.hours > eff_target:
                return False

            # RESERVATION Check — FIX #8: use eff_target, not target_hours
            if shift_type != ShiftType.NIGHT:
                nights_done = n.count_shift_type(ShiftType.NIGHT)
                nights_needed = max(0, target_nights - nights_done)
                hours_reserved_for_nights = nights_needed * 12
                hours_remaining = eff_target - current_total

                if (hours_remaining - shift_type.hours) < hours_reserved_for_nights:
                    return False

            return True

        def weekly_night_ok(n: Nurse, day: int) -> bool:
            """FIX #3: Max 2 nights in any 7-day window."""
            return Scheduler._nights_in_window(n, day) < 2

        def prefer_evening_after_night_off(n: Nurse, d: int) -> bool:
            """FIX #5: Gradual rotation — returns True if nurse should prefer E over M."""
            if d >= 3:
                return n.get_shift(d - 2) == ShiftType.NIGHT  # d-2 was Night, d-1 was OFF
            return False

        def fairness_key(n: Nurse):
            return (n.count_weekend_shifts(year, month), n.count_holiday_shifts(holidays))

        def night_sort_key(n):
            nights_done = n.count_shift_type(ShiftType.NIGHT)
            nights_remaining = target_nights - nights_done
            return (nights_remaining,
                    -n.count_weekend_shifts(year, month),
                    -n.count_holiday_shifts(holidays),
                    get_effective_target_hours(n) - n.calculate_total_hours())

        # ========================================================
        # MAIN ASSIGNMENT LOOP
        # ========================================================
        for d_idx, d in enumerate(days):
            target_this_day = schedule_targets[d]
            req_n = night_targets[d]
            target_day_shifts = max(0, target_this_day - req_n)
            req_m = int(target_day_shifts * ratio_m)
            req_e = int(target_day_shifts - req_m)

            # FIX #6: Safety Min Staffing — req >= 2 when pool allows
            min_per_shift = 2 if total_pool >= 6 else 1
            req_n = max(min_per_shift, req_n)
            req_e = max(min_per_shift, req_e)
            req_m = max(min_per_shift, req_m)

            # A. Forced OFF (Post-Night rule — "Sleep Day")
            forced_off = []
            if d > 1:
                for n in pool:
                    if n.get_shift(d - 1) == ShiftType.NIGHT:
                        n.assign_shift(d, ShiftType.OFF)
                        forced_off.append(n)

            # B. Availability
            available = [n for n in pool if d not in n.shifts]
            random.shuffle(available)

            # Track PNs per shift
            pn_assigned_n = 0
            pn_assigned_e = 0
            pn_assigned_m = 0

            # ---- C. Assign NIGHTS ----
            nights_assigned = 0

            valid_night_candidates = []
            for n in available:
                if needs_night(n) and can_take_shift(n, ShiftType.NIGHT):
                    if not (d > 1 and n.get_shift(d - 1) == ShiftType.NIGHT):
                        if weekly_night_ok(n, d):  # FIX #3
                            valid_night_candidates.append(n)

            candidates_pn = [n for n in valid_night_candidates if n.role == "PN"]
            candidates_tn = [n for n in valid_night_candidates if n.role != "PN"]
            candidates_pn.sort(key=night_sort_key, reverse=True)
            candidates_tn.sort(key=night_sort_key, reverse=True)

            # Must assign 1 PN first
            if req_n > 0 and candidates_pn:
                n = candidates_pn.pop(0)
                n.assign_shift(d, ShiftType.NIGHT)
                available.remove(n)
                nights_assigned += 1
                pn_assigned_n += 1

            # Fill remainder (prefer TNs to save PNs)
            remainder = candidates_tn + candidates_pn
            for n in remainder:
                if nights_assigned < req_n:
                    n.assign_shift(d, ShiftType.NIGHT)
                    available.remove(n)
                    nights_assigned += 1
                    if n.role == "PN":
                        pn_assigned_n += 1
                else:
                    break

            # Panic Mode Night: Missing PN
            if req_n > 0 and pn_assigned_n == 0:
                avail_pns = [n for n in available if n.role == "PN"]
                avail_pns.sort(key=lambda n: n.count_shift_type(ShiftType.NIGHT))
                for n in avail_pns:
                    if d > 1 and n.get_shift(d - 1) == ShiftType.NIGHT:
                        continue
                    n.assign_shift(d, ShiftType.NIGHT)
                    available.remove(n)
                    nights_assigned += 1
                    pn_assigned_n += 1
                    break

            # Panic Mode Night: Understaffed
            while nights_assigned < req_n:
                candidates = [n for n in available if n.role in ("PN", "TN")]
                if not candidates:
                    break
                candidates.sort(key=lambda n: n.count_shift_type(ShiftType.NIGHT))
                found = False
                for n in candidates:
                    if d > 1 and n.get_shift(d - 1) == ShiftType.NIGHT:
                        continue
                    n.assign_shift(d, ShiftType.NIGHT)
                    available.remove(n)
                    nights_assigned += 1
                    if n.role == "PN":
                        pn_assigned_n += 1
                    found = True
                    break
                if not found:
                    break

            # ---- D. Assign EVENINGS ----
            evenings_assigned = 0

            # FIX #5: Gradual rotation — nurses returning from Night-OFF prefer Evening
            prefer_e = [n for n in available if prefer_evening_after_night_off(n, d)
                        and needs_hours(n) and can_take_shift(n, ShiftType.EVENING)]

            # Assign preferred E candidates first
            for n in prefer_e:
                if evenings_assigned < req_e:
                    n.assign_shift(d, ShiftType.EVENING)
                    available.remove(n)
                    evenings_assigned += 1
                    if n.role == "PN":
                        pn_assigned_e += 1
                else:
                    break

            valid_evening_candidates = [n for n in available
                                        if needs_hours(n) and can_take_shift(n, ShiftType.EVENING)]

            e_candidates_pn = [n for n in valid_evening_candidates if n.role == "PN"]
            e_candidates_other = [n for n in valid_evening_candidates if n.role != "PN"]

            # Ensure 1 PN in Evening
            if req_e > 0 and pn_assigned_e == 0 and e_candidates_pn:
                n = e_candidates_pn.pop(0)
                n.assign_shift(d, ShiftType.EVENING)
                available.remove(n)
                evenings_assigned += 1
                pn_assigned_e += 1

            e_remainder = e_candidates_other + e_candidates_pn
            e_remainder.sort(key=lambda n: (
                -n.count_weekend_shifts(year, month),
                -n.count_holiday_shifts(holidays),
                get_effective_target_hours(n) - n.calculate_total_hours()
            ), reverse=True)

            for n in e_remainder:
                if evenings_assigned < req_e:
                    n.assign_shift(d, ShiftType.EVENING)
                    available.remove(n)
                    evenings_assigned += 1
                    if n.role == "PN":
                        pn_assigned_e += 1
                else:
                    break

            # Panic Mode Evening: Missing PN
            if req_e > 0 and pn_assigned_e == 0:
                avail_pns = [n for n in available if n.role == "PN"]
                avail_pns.sort(key=lambda n: get_effective_target_hours(n) - n.calculate_total_hours(), reverse=True)
                for n in avail_pns:
                    n.assign_shift(d, ShiftType.EVENING)
                    available.remove(n)
                    evenings_assigned += 1
                    pn_assigned_e += 1
                    break

            while evenings_assigned < req_e:
                candidates = [n for n in available if n.role in ("PN", "TN")]
                if not candidates:
                    break
                candidates.sort(key=lambda n: get_effective_target_hours(n) - n.calculate_total_hours(), reverse=True)
                n = candidates[0]
                n.assign_shift(d, ShiftType.EVENING)
                available.remove(n)
                evenings_assigned += 1
                if n.role == "PN":
                    pn_assigned_e += 1

            # ---- E. Assign MORNINGS ----
            mornings_assigned = 0

            valid_morning_candidates = [n for n in available
                                        if needs_hours(n) and can_take_shift(n, ShiftType.MORNING)]

            m_candidates_pn = [n for n in valid_morning_candidates if n.role == "PN"]
            m_candidates_other = [n for n in valid_morning_candidates if n.role != "PN"]

            if req_m > 0 and m_candidates_pn:
                n = m_candidates_pn.pop(0)
                n.assign_shift(d, ShiftType.MORNING)
                available.remove(n)
                mornings_assigned += 1
                pn_assigned_m += 1

            m_remainder = m_candidates_other + m_candidates_pn
            m_remainder.sort(key=lambda n: (
                -n.count_weekend_shifts(year, month),
                -n.count_holiday_shifts(holidays),
                get_effective_target_hours(n) - n.calculate_total_hours()
            ), reverse=True)

            for n in m_remainder:
                if mornings_assigned < req_m:
                    n.assign_shift(d, ShiftType.MORNING)
                    available.remove(n)
                    mornings_assigned += 1
                    if n.role == "PN":
                        pn_assigned_m += 1
                else:
                    break

            # Panic Mode Morning: Missing PN
            if req_m > 0 and pn_assigned_m == 0:
                avail_pns = [n for n in available if n.role == "PN"]
                avail_pns.sort(key=lambda n: get_effective_target_hours(n) - n.calculate_total_hours(), reverse=True)
                for n in avail_pns:
                    n.assign_shift(d, ShiftType.MORNING)
                    available.remove(n)
                    mornings_assigned += 1
                    pn_assigned_m += 1
                    break

            while mornings_assigned < req_m:
                candidates = [n for n in available if n.role in ("PN", "TN")]
                if not candidates:
                    break
                candidates.sort(key=lambda n: get_effective_target_hours(n) - n.calculate_total_hours(), reverse=True)
                n = candidates[0]
                n.assign_shift(d, ShiftType.MORNING)
                available.remove(n)
                mornings_assigned += 1
                if n.role == "PN":
                    pn_assigned_m += 1

            # F. Rest are OFF
            for n in available:
                n.assign_shift(d, ShiftType.OFF)

        # ========================================================
        # POST-PROCESSING PASSES
        # ========================================================

        # FIX #2: Holiday Next-Day Off
        # If nurse worked on holiday day h, try to give OFF on h+1
        for h in holidays:
            h_next = h + 1
            if h_next > days_in_month:
                continue
            for n in pool:
                if n.get_shift(h) != ShiftType.OFF and n.get_shift(h_next) != ShiftType.OFF:
                    # Try to swap: find a nurse who is OFF on h_next and didn't work h
                    swapped = False
                    for other in pool:
                        if other == n:
                            continue
                        if (other.get_shift(h_next) == ShiftType.OFF
                                and other.get_shift(h) == ShiftType.OFF
                                and can_take_shift(other, n.get_shift(h_next))):
                            # Swap shifts
                            shift_to_swap = n.get_shift(h_next)
                            other.assign_shift(h_next, shift_to_swap)
                            n.assign_shift(h_next, ShiftType.OFF)
                            swapped = True
                            break
                    # If no swap possible, just mark as attempted

        # FIX #4: Weekly Rest — ensure min 1 OFF per calendar week
        # Check in 7-day windows (weeks of the month)
        for n in pool:
            for week_start in range(1, days_in_month + 1, 7):
                week_end = min(week_start + 6, days_in_month)
                if not Scheduler._has_off_in_week(n, week_start, week_end):
                    # Force OFF on the day with fewest staff
                    best_day = None
                    best_count = 999
                    for wd in range(week_start, week_end + 1):
                        if n.get_shift(wd) in (ShiftType.MORNING, ShiftType.EVENING):
                            day_count = sum(1 for o in pool if o.get_shift(wd) != ShiftType.OFF)
                            if day_count > best_count or best_day is None:
                                best_day = wd
                                best_count = day_count
                    if best_day is not None:
                        n.assign_shift(best_day, ShiftType.OFF)

        return nurses
