from enum import Enum
from typing import Dict, Optional

class ShiftType(Enum):
    MORNING = "M"
    EVENING = "E"
    NIGHT = "N"
    OFF = "OFF"
    
    @property
    def hours(self) -> int:
        if self == ShiftType.NIGHT:
            return 12
        elif self in (ShiftType.MORNING, ShiftType.EVENING):
            return 6
        return 0

class Nurse:
    def __init__(self, name: str, role: str):
        self.name = name
        self.role = role  # HN, Asst, PN, TN
        self.shifts: Dict[int, ShiftType] = {} # Day number -> ShiftType
        
    def assign_shift(self, day: int, shift: ShiftType):
        self.shifts[day] = shift
        
    def get_shift(self, day: int) -> ShiftType:
        return self.shifts.get(day, ShiftType.OFF)
        
    def calculate_total_hours(self) -> int:
        total = 0
        for shift in self.shifts.values():
            total += shift.hours
        return total

    def count_shift_type(self, shift_type: ShiftType) -> int:
        return sum(1 for s in self.shifts.values() if s == shift_type)

    def __repr__(self):
        return f"Nurse({self.name}, {self.role}, Hrs={self.calculate_total_hours()})"

    def count_weekend_shifts(self, year: int, month: int) -> int:
        count = 0
        from datetime import date
        for d, s in self.shifts.items():
            if s != ShiftType.OFF:
                try:
                    wd = date(year, month, d).weekday()
                    if wd == 4 or wd == 5: # Fri is 4, Sat is 5
                        count += 1
                except ValueError:
                    pass # Invalid date
        return count

    def count_holiday_shifts(self, holidays) -> int:
        return sum(1 for d, s in self.shifts.items() if d in holidays and s != ShiftType.OFF)
