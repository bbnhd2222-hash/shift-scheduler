import 'dart:math';
import '../models/nurse.dart';
import '../models/shift_type.dart';

class Scheduler {
  int getMonthDays(int year, int month) {
    if (month == 12) return 31;
    return DateTime(year, month + 1, 0).day;
  }

  bool isFriday(int year, int month, int day) {
    return DateTime(year, month, day).weekday == DateTime.friday;
  }

  bool isSaturday(int year, int month, int day) {
    return DateTime(year, month, day).weekday == DateTime.saturday;
  }

  bool isSunday(int year, int month, int day) {
    return DateTime(year, month, day).weekday == DateTime.sunday;
  }

  static int _nightsInWindow(Nurse nurse, int centerDay, {int window = 7}) {
    int count = 0;
    int start = max(1, centerDay - window + 1);
    for (int d = start; d <= centerDay; d++) {
      if (nurse.getShift(d) == ShiftType.night) {
        count++;
      }
    }
    return count;
  }

  static bool _hasOffInWeek(Nurse nurse, int weekStart, int weekEnd) {
    for (int d = weekStart; d <= weekEnd; d++) {
      if (nurse.getShift(d) == ShiftType.off) {
        return true;
      }
    }
    return false;
  }

  // Extensions on Nurse for context calculations
  int countHolidayShifts(Nurse n, List<int> holidays) {
    int count = 0;
    for (int h in holidays) {
      if (n.getShift(h) != ShiftType.off) {
        count++;
      }
    }
    return count;
  }

  int countWeekendShifts(Nurse n, int year, int month) {
    int count = 0;
    for (int d in n.shifts.keys) {
      if (isFriday(year, month, d) || isSaturday(year, month, d)) {
        if (n.getShift(d) != ShiftType.off) count++;
      }
    }
    return count;
  }

  List<Nurse> generateSchedule(
    int year,
    int month,
    Map<String, int> staffConfig,
    List<int> holidays, {
    int targetHours = 160,
    int targetNights = 4,
  }) {
    List<Nurse> nurses = [];
    
    int hnCount = staffConfig['HN'] ?? 0;
    for (int i = 0; i < hnCount; i++) {
      nurses.add(Nurse("HN ${i + 1}", "HN"));
    }
    int asstCount = staffConfig['Asst'] ?? 0;
    for (int i = 0; i < asstCount; i++) {
      nurses.add(Nurse("Asst ${i + 1}", "Asst"));
    }
    int pnCount = staffConfig['PN'] ?? 0;
    for (int i = 0; i < pnCount; i++) {
      nurses.add(Nurse("PN ${i + 1}", "PN"));
    }
    int tnCount = staffConfig['TN'] ?? 0;
    for (int i = 0; i < tnCount; i++) {
      nurses.add(Nurse("TN ${i + 1}", "TN"));
    }

    int daysInMonth = getMonthDays(year, month);
    List<int> days = List.generate(daysInMonth, (i) => i + 1);

    List<Nurse> hns = nurses.where((n) => n.role == "HN").toList();
    List<Nurse> assts = nurses.where((n) => n.role == "Asst").toList();
    List<Nurse> pool = nurses.where((n) => n.role == "PN" || n.role == "TN").toList();

    // STEP 1: Leadership Schedule
    for (var hn in hns) {
      for (int d in days) {
        if (isFriday(year, month, d) || holidays.contains(d)) {
          hn.assignShift(d, ShiftType.off);
        } else {
          hn.assignShift(d, ShiftType.morning);
        }
      }
    }

    for (var asst in assts) {
      for (int d in days) {
        // Offset Assistant to Wednesday if HN is off Friday (guarantees 1 day gap via Thursday)
        bool isWednesday = DateTime(year, month, d).weekday == DateTime.wednesday;
        if (isWednesday || holidays.contains(d)) {
          asst.assignShift(d, ShiftType.off);
        } else {
          asst.assignShift(d, ShiftType.morning);
        }
      }
    }

    // Leadership fix: No same day off
    for (int d in days) {
      bool allHnOff = hns.isEmpty ? true : hns.every((hn) => hn.getShift(d) == ShiftType.off);
      bool allAsstOff = assts.isEmpty ? true : assts.every((a) => a.getShift(d) == ShiftType.off);

      if (hns.isNotEmpty && assts.isNotEmpty && allHnOff && allAsstOff) {
        for (var a in assts) {
          a.assignShift(d, ShiftType.morning);
        }
      }
    }

    // STEP 2: General Pool Configuration
    int totalPool = pool.length;
    int daysCount = days.length;
    
    int baseOther = 0;
    int baseFriday = 0;
    int extras = 0;
    int baseN = 0;
    int extraN = 0;
    double ratioM = 0.5;

    if (totalPool > 0 && daysCount > 0) {
      int totalNightSlots = targetNights * totalPool;
      int totalNightHours = totalNightSlots * 12;
      
      // Calculate total day shifts needed to reach target hours
      int totalPoolHours = targetHours * totalPool;
      int totalDayHours = max(0, totalPoolHours - totalNightHours);
      int totalDayShifts = totalDayHours ~/ 6;

      int countFridays = days.where((d) => isFriday(year, month, d)).length;
      int countOthers = daysCount - countFridays;
      int xGap = 2; // Reduce Friday quota

      double avgTargetOther = (totalDayShifts + (xGap * countFridays)) / daysCount;
      baseOther = avgTargetOther.toInt();
      baseFriday = max(0, baseOther - xGap);

      int guaranteed = (baseOther * countOthers) + (baseFriday * countFridays);
      extras = max(0, totalDayShifts - guaranteed);

      baseN = totalNightSlots ~/ daysCount;
      extraN = totalNightSlots % daysCount;

      // Desired Ratio: Morning 45%, Evening 37% (Total Day = 82%) => Morning / Day = 45 / 82
      ratioM = 45 / 82;
    }

    Map<int, int> scheduleTargets = {};
    for (int d in days) {
      if (isFriday(year, month, d)) {
        scheduleTargets[d] = baseFriday;
      } else {
        scheduleTargets[d] = baseOther;
      }
    }

    List<int> dayIndices = List.generate(daysCount, (i) => i + 1);
    for (int i = 0; i < extras; i++) {
      int d = dayIndices[i % daysCount];
      scheduleTargets[d] = (scheduleTargets[d] ?? 0) + 1;
    }

    Map<int, int> nightTargets = {};
    for (int d in days) {
      nightTargets[d] = baseN;
    }
    for (int i = 0; i < extraN; i++) {
      int d = dayIndices[i % daysCount];
      nightTargets[d] = (nightTargets[d] ?? 0) + 1;
    }

    int getEffectiveTargetHours(Nurse n) {
      int hShifts = countHolidayShifts(n, holidays);
      return targetHours - (hShifts * 6);
    }

    bool needsNight(Nurse n) {
      return n.countShiftType(ShiftType.night) < targetNights;
    }

    bool needsHours(Nurse n) {
      return n.getTotalHours() < getEffectiveTargetHours(n);
    }

    bool canTakeShift(Nurse n, ShiftType shiftType) {
      int effTarget = getEffectiveTargetHours(n);
      if (shiftType == ShiftType.night && needsNight(n)) return true;

      int currentTotal = n.getTotalHours();
      if (currentTotal + shiftType.hours > effTarget) return false;

      if (shiftType != ShiftType.night) {
        int nightsDone = n.countShiftType(ShiftType.night);
        int nightsNeeded = max(0, targetNights - nightsDone);
        int hoursReservedForNights = nightsNeeded * 12;
        int hoursRemaining = effTarget - currentTotal;

        if ((hoursRemaining - shiftType.hours) < hoursReservedForNights) {
          return false;
        }
      }
      return true;
    }

    bool weeklyNightOk(Nurse n, int day) {
      return _nightsInWindow(n, day) < 2;
    }

    bool preferEveningAfterNightOff(Nurse n, int d) {
      if (d >= 3) {
        return n.getShift(d - 2) == ShiftType.night;
      }
      return false;
    }

    int nightSortKeyVal(Nurse n) {
      // Calculate a comparable score for sorting. Higher needs come first.
      int nightsRemaining = targetNights - n.countShiftType(ShiftType.night);
      int weekend = countWeekendShifts(n, year, month);
      int hol = countHolidayShifts(n, holidays);
      int hrDiff = getEffectiveTargetHours(n) - n.getTotalHours();
      
      // Dart doesn't have tuple sort, we use a scoring or compare loop
      // But simple enough: prioritize nightsRemaining, then HR diff, penalize weekend/hols
      return (nightsRemaining * 100000) + (hrDiff * 100) - (weekend * 10) - hol;
    }

    // --- PER THE ALGORITHM FIX REPORT ---
    // If it's a 31 day month and we need exactly 144 hours (4 nights):
    // Staggered 31-day Sequence: N, O, M, M, E, E, O, N, O, M, M, E, E, O, N, O, M, M, E, E, O, N, O, M, M, E, E, O, O, O, O.
    // Total: 4xN (48) + 8xM (48) + 8xE (48) = 144 Hours.
    if (daysCount == 31 && targetHours == 144 && targetNights == 4) {
       List<ShiftType> base31Array = [
          ShiftType.night, ShiftType.off, ShiftType.morning, ShiftType.morning, ShiftType.evening, ShiftType.evening, ShiftType.off,
          ShiftType.night, ShiftType.off, ShiftType.morning, ShiftType.morning, ShiftType.evening, ShiftType.evening, ShiftType.off,
          ShiftType.night, ShiftType.off, ShiftType.morning, ShiftType.morning, ShiftType.evening, ShiftType.evening, ShiftType.off,
          ShiftType.night, ShiftType.off, ShiftType.morning, ShiftType.morning, ShiftType.evening, ShiftType.evening, ShiftType.off,
          ShiftType.off, ShiftType.off, ShiftType.off
       ];

       // We shift the index each month so nurses don't get locked into the exact same pattern (e.g. working every Friday forever).
       int monthOffset = (month * 7) % 31; 

       int nurseIndex = 0;
       for (var n in pool) {
          int staggerOffset = (nurseIndex * 3) + monthOffset; // Stagger each nurse by 3 days
          for (int d in days) {
              int arrayIndex = ((d - 1) + staggerOffset) % 31;
              n.assignShift(d, base31Array[arrayIndex]);
          }
          nurseIndex++;
       }
    } else {
      // FALLLBACK: Standard Randomization Generator for non-31-day months or custom hours
      var random = Random();
      for (int d in days) {
        int targetThisDay = scheduleTargets[d] ?? 0;
        int reqN = nightTargets[d] ?? 0;
        int targetDayShifts = max(0, targetThisDay - reqN);
        int reqM = (targetDayShifts * ratioM).toInt();
        
        int minPerShift = totalPool >= 6 ? 2 : 1;
        if (isFriday(year, month, d)) {
          reqM = max(minPerShift, reqM - 1);
        }
        
        int reqE = targetDayShifts - reqM;

        reqN = max(minPerShift, reqN);
        reqE = max(minPerShift, reqE);
        reqM = max(minPerShift, reqM);

        if (d > 1) {
          for (var n in pool) {
            if (n.getShift(d - 1) == ShiftType.night) {
              n.assignShift(d, ShiftType.off);
            }
          }
        }

        List<Nurse> available = pool.where((n) => !n.shifts.containsKey(d)).toList();
        available.shuffle(random);

        int pnAssignedN = 0, pnAssignedE = 0, pnAssignedM = 0;

        int nightsAssigned = 0;
        List<Nurse> validNightCandidates = available.where((n) => 
          needsNight(n) && canTakeShift(n, ShiftType.night) &&
          !(d > 1 && n.getShift(d - 1) == ShiftType.night) &&
          weeklyNightOk(n, d)
        ).toList();

        List<Nurse> candidatesPN = validNightCandidates.where((n) => n.role == "PN").toList();
        List<Nurse> candidatesTN = validNightCandidates.where((n) => n.role != "PN").toList();
        
        candidatesPN.sort((a, b) => nightSortKeyVal(b).compareTo(nightSortKeyVal(a)));
        candidatesTN.sort((a, b) => nightSortKeyVal(b).compareTo(nightSortKeyVal(a)));

        if (reqN > 0 && candidatesPN.isNotEmpty) {
          var n = candidatesPN.removeAt(0);
          n.assignShift(d, ShiftType.night);
          available.remove(n);
          nightsAssigned++;
          pnAssignedN++;
        }

        List<Nurse> remainderN = [...candidatesTN, ...candidatesPN];
        for (var n in remainderN) {
          if (nightsAssigned < reqN) {
            n.assignShift(d, ShiftType.night);
            available.remove(n);
            nightsAssigned++;
            if (n.role == "PN") pnAssignedN++;
          } else {
            break;
          }
        }

        if (reqN > 0 && pnAssignedN == 0) {
          var availPNs = available.where((n) => n.role == "PN").toList();
          availPNs.sort((a, b) => a.countShiftType(ShiftType.night).compareTo(b.countShiftType(ShiftType.night)));
          for (var n in availPNs) {
            if (d > 1 && n.getShift(d - 1) == ShiftType.night) continue;
            n.assignShift(d, ShiftType.night);
            available.remove(n);
            nightsAssigned++;
            pnAssignedN++;
            break;
          }
        }

        while (nightsAssigned < reqN) {
          var candidates = available.where((n) => n.role == "PN" || n.role == "TN").toList();
          if (candidates.isEmpty) break;
          candidates.sort((a, b) => a.countShiftType(ShiftType.night).compareTo(b.countShiftType(ShiftType.night)));
          bool found = false;
          for (var n in candidates) {
            if (d > 1 && n.getShift(d - 1) == ShiftType.night) continue;
            n.assignShift(d, ShiftType.night);
            available.remove(n);
            nightsAssigned++;
            if (n.role == "PN") pnAssignedN++;
            found = true;
            break;
          }
          if (!found) break;
        }

        int eveningsAssigned = 0;
        List<Nurse> preferE = available.where((n) =>
          preferEveningAfterNightOff(n, d) && needsHours(n) && canTakeShift(n, ShiftType.evening)
        ).toList();

        for (var n in preferE) {
          if (eveningsAssigned < reqE) {
            n.assignShift(d, ShiftType.evening);
            available.remove(n);
            eveningsAssigned++;
            if (n.role == "PN") pnAssignedE++;
          } else {
            break;
          }
        }

        List<Nurse> validECandidates = available.where((n) => needsHours(n) && canTakeShift(n, ShiftType.evening)).toList();
        List<Nurse> eCandidatesPN = validECandidates.where((n) => n.role == "PN").toList();
        List<Nurse> eCandidatesOther = validECandidates.where((n) => n.role != "PN").toList();

        if (reqE > 0 && pnAssignedE == 0 && eCandidatesPN.isNotEmpty) {
          var n = eCandidatesPN.removeAt(0);
          n.assignShift(d, ShiftType.evening);
          available.remove(n);
          eveningsAssigned++;
          pnAssignedE++;
        }

        int genSortKey(Nurse n) {
           int weekend = countWeekendShifts(n, year, month);
           int hol = countHolidayShifts(n, holidays);
           int hrDiff = getEffectiveTargetHours(n) - n.getTotalHours();
           return (hrDiff * 100) - (weekend * 10) - hol;
        }

        List<Nurse> eRemainder = [...eCandidatesOther, ...eCandidatesPN];
        eRemainder.sort((a, b) => genSortKey(b).compareTo(genSortKey(a)));

        for (var n in eRemainder) {
          if (eveningsAssigned < reqE) {
            n.assignShift(d, ShiftType.evening);
            available.remove(n);
            eveningsAssigned++;
            if (n.role == "PN") pnAssignedE++;
          } else {
            break;
          }
        }

        if (reqE > 0 && pnAssignedE == 0) {
          var availPNs = available.where((n) => n.role == "PN").toList();
          availPNs.sort((a, b) => (getEffectiveTargetHours(b) - b.getTotalHours()).compareTo(getEffectiveTargetHours(a) - a.getTotalHours()));
          for (var n in availPNs) {
            n.assignShift(d, ShiftType.evening);
            available.remove(n);
            eveningsAssigned++;
            pnAssignedE++;
            break;
          }
        }

        while (eveningsAssigned < reqE) {
          var candidates = available.where((n) => n.role == "PN" || n.role == "TN").toList();
          if (candidates.isEmpty) break;
          candidates.sort((a, b) => (getEffectiveTargetHours(b) - b.getTotalHours()).compareTo(getEffectiveTargetHours(a) - a.getTotalHours()));
          var n = candidates[0];
          n.assignShift(d, ShiftType.evening);
          available.remove(n);
          eveningsAssigned++;
          if (n.role == "PN") pnAssignedE++;
        }

        int morningsAssigned = 0;
        List<Nurse> validMCandidates = available.where((n) => needsHours(n) && canTakeShift(n, ShiftType.morning)).toList();
        List<Nurse> mCandidatesPN = validMCandidates.where((n) => n.role == "PN").toList();
        List<Nurse> mCandidatesOther = validMCandidates.where((n) => n.role != "PN").toList();

        if (reqM > 0 && mCandidatesPN.isNotEmpty) {
          var n = mCandidatesPN.removeAt(0);
          n.assignShift(d, ShiftType.morning);
          available.remove(n);
          morningsAssigned++;
          pnAssignedM++;
        }

        List<Nurse> mRemainder = [...mCandidatesOther, ...mCandidatesPN];
        mRemainder.sort((a, b) => genSortKey(b).compareTo(genSortKey(a)));

        for (var n in mRemainder) {
          if (morningsAssigned < reqM) {
            n.assignShift(d, ShiftType.morning);
            available.remove(n);
            morningsAssigned++;
            if (n.role == "PN") pnAssignedM++;
          } else {
            break;
          }
        }

        if (reqM > 0 && pnAssignedM == 0) {
          var availPNs = available.where((n) => n.role == "PN").toList();
          availPNs.sort((a, b) => (getEffectiveTargetHours(b) - b.getTotalHours()).compareTo(getEffectiveTargetHours(a) - a.getTotalHours()));
          for (var n in availPNs) {
            n.assignShift(d, ShiftType.morning);
            available.remove(n);
            morningsAssigned++;
            pnAssignedM++;
            break;
          }
        }

        while (morningsAssigned < reqM) {
          var candidates = available.where((n) => n.role == "PN" || n.role == "TN").toList();
          if (candidates.isEmpty) break;
          candidates.sort((a, b) => (getEffectiveTargetHours(b) - b.getTotalHours()).compareTo(getEffectiveTargetHours(a) - a.getTotalHours()));
          var n = candidates[0];
          n.assignShift(d, ShiftType.morning);
          available.remove(n);
          morningsAssigned++;
          if (n.role == "PN") pnAssignedM++;
        }

        for (var n in available) {
          n.assignShift(d, ShiftType.off);
        }
      }
    }

    // POST-PROCESSING: Multi-day Holiday Swap (Force day 2 off if day 1 worked)
    for (int h in holidays) {
      int hNext = h + 1;
      if (hNext > daysInMonth) continue;
      if (!holidays.contains(hNext)) continue; // Must be consecutive holidays

      for (var n in pool) {
        if (n.getShift(h) != ShiftType.off && n.getShift(hNext) != ShiftType.off) {
          for (var other in pool.where((o) => o.role == n.role)) { // ONLY swap like-for-like
            if (other == n) continue;
            if (other.getShift(hNext) == ShiftType.off && 
                other.getShift(h) == ShiftType.off && 
                canTakeShift(other, n.getShift(hNext))) {
              var shiftToSwap = n.getShift(hNext);
              other.assignShift(hNext, shiftToSwap);
              n.assignShift(hNext, ShiftType.off);
              break;
            }
          }
        }
      }
    }

    // POST-PROCESSING: Weekly Rest
    for (var n in pool) {
      for (int weekStart = 1; weekStart <= daysInMonth; weekStart += 7) {
        int weekEnd = min(weekStart + 6, daysInMonth);
        if (!_hasOffInWeek(n, weekStart, weekEnd)) {
          int? bestDay;
          int bestCount = 999;
          for (int wd = weekStart; wd <= weekEnd; wd++) {
            if (n.getShift(wd) == ShiftType.morning || n.getShift(wd) == ShiftType.evening) {
              int dayCount = pool.where((o) => o.getShift(wd) != ShiftType.off).length;
              if (dayCount < bestCount || bestDay == null) {
                bestDay = wd;
                bestCount = dayCount;
              }
            }
          }
          if (bestDay != null) {
            n.assignShift(bestDay, ShiftType.off);
          }
        }
      }
    }

    // POST-PROCESSING: Validation Gate - Never Alone Skill Mix (PN Supervision)
    for (int d in days) {
      for (var shiftType in [ShiftType.night, ShiftType.evening, ShiftType.morning]) {
        var nursesOnShift = pool.where((n) => n.getShift(d) == shiftType).toList();
        var pnsOnShift = nursesOnShift.where((n) => n.role == "PN").length;
        var tnsOnShift = nursesOnShift.where((n) => n.role == "TN").length;
        
        if (tnsOnShift > 0 && pnsOnShift == 0) {
          var availablePns = pool.where((n) => 
            n.role == "PN" && 
            n.getShift(d) == ShiftType.off &&
            (d == 1 || n.getShift(d-1) != ShiftType.night) &&
            n.getTotalHours() <= 156
          ).toList();
          if (availablePns.isNotEmpty) {
            availablePns.first.assignShift(d, shiftType);
          } else {
             // Understaffed is legally better than illegal isolation.
             for(var tn in nursesOnShift.where((n) => n.role == "TN")) { tn.assignShift(d, ShiftType.off); }
          }
        }
      }
    }

    // POST-PROCESSING: Validation Gate - Clamp Total Hours (144 - 162)
    for (var n in pool) {
      while (n.getTotalHours() > 162) {
        var possibleDays = days.where((d) => n.getShift(d) == ShiftType.morning || n.getShift(d) == ShiftType.evening).toList();
        if (possibleDays.isEmpty) break;
        n.assignShift(possibleDays[0], ShiftType.off);
      }
      while (n.getTotalHours() < 144) {
        var possibleDays = days.where((d) => 
          n.getShift(d) == ShiftType.off && 
          (d == 1 || n.getShift(d-1) != ShiftType.night) &&
          (d == daysInMonth || n.getShift(d+1) != ShiftType.night)
        ).toList();
        if (possibleDays.isEmpty) break;
        // Prioritize morning shifts to boost totals without altering night equity
        n.assignShift(possibleDays.first, ShiftType.morning); 
      }
    }

    // POST-PROCESSING: Calculate Final metrics for UI tracking
    for (var n in nurses) {
      n.fridaysWorked = 0;
      n.holidaysWorked = 0;
      for (int d in days) {
        if (n.getShift(d) != ShiftType.off) {
          if (isFriday(year, month, d)) n.fridaysWorked++;
          if (holidays.contains(d)) n.holidaysWorked++;
        }
      }
    }

    return nurses;
  }
}
