import 'shift_type.dart';

class Nurse {
  final String name;
  final String role; // HN, Asst, PN, TN
  final Map<int, ShiftType> shifts = {}; // Day number -> ShiftType

  Nurse(this.name, this.role);

  void clearSchedule() {
    shifts.clear();
  }

  void assignShift(int day, ShiftType shift) {
    shifts[day] = shift;
  }

  ShiftType getShift(int day) {
    return shifts[day] ?? ShiftType.off;
  }

  int countShiftType(ShiftType type) {
    int count = 0;
    for (var shift in shifts.values) {
      if (shift == type) count++;
    }
    return count;
  }

  int countRestDays() {
    return countShiftType(ShiftType.off);
  }

  int getTotalHours() {
    int total = 0;
    for (var shift in shifts.values) {
      total += shift.hours;
    }
    return total;
  }

  void resetBackTo(int endDay) {
    final keysToRemove = shifts.keys.where((k) => k > endDay).toList();
    for (var k in keysToRemove) {
      shifts.remove(k);
    }
  }

  int consecutiveNights() {
    int maxConsecutive = 0;
    int currentSequence = 0;

    for (int day = 1; day <= 31; day++) {
      if (getShift(day) == ShiftType.night) {
        currentSequence++;
        if (currentSequence > maxConsecutive) {
          maxConsecutive = currentSequence;
        }
      } else if (getShift(day) != ShiftType.off || getShift(day) != ShiftType.night) {
        currentSequence = 0;
      }
    }
    return maxConsecutive;
  }

  int consecutiveMorningsOrEvenings() {
    int maxConsecutive = 0;
    int currentSequence = 0;

    for (int day = 1; day <= 31; day++) {
      var shift = getShift(day);
      if (shift == ShiftType.morning || shift == ShiftType.evening) {
        currentSequence++;
        if (currentSequence > maxConsecutive) {
          maxConsecutive = currentSequence;
        }
      } else if (shift != ShiftType.off) {
        currentSequence = 0;
      } else {
        currentSequence = 0;
      }
    }
    return maxConsecutive;
  }
}
