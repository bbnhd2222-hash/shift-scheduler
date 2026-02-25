enum ShiftType {
  morning('M'),
  evening('E'),
  night('N'),
  off('OFF');

  final String value;
  const ShiftType(this.value);

  int get hours {
    switch (this) {
      case ShiftType.night:
        return 12;
      case ShiftType.morning:
      case ShiftType.evening:
        return 6;
      case ShiftType.off:
        return 0;
    }
  }
}
