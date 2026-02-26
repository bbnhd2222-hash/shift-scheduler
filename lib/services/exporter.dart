import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/nurse.dart';
import '../models/shift_type.dart';

class Exporter {
  static Future<Uint8List?> exportToExcel(
      List<Nurse> nurses, int year, int month) async {
    var excel = Excel.createExcel();
    // Bypassing a bug in the Excel package where renaming throws "Unsupported operation"
    var sheetName = excel.getDefaultSheet() ?? "Sheet1";
    var ws = excel[sheetName];

    // Headers
    List<dynamic> headers = ["No.", "Name"];
    for (int d = 1; d <= 31; d++) {
      headers.add(d.toString());
    }
    headers.addAll([
      "M Hours",
      "E Hours",
      "N Hours",
      "Total Hours"
    ]);
    ws.appendRow(headers);

    // Row Data
    for (int i = 0; i < nurses.length; i++) {
      var nurse = nurses[i];
      List<dynamic> row = [
        (i + 1),
        nurse.name
      ];

      for (int d = 1; d <= 31; d++) {
        var shift = nurse.getShift(d);
        if (shift != ShiftType.off) {
          row.add(shift.value);
        } else {
          row.add(""); // Empty for OFF
        }
      }

      int mHrs = nurse.countShiftType(ShiftType.morning) * 6;
      int eHrs = nurse.countShiftType(ShiftType.evening) * 6;
      int nHrs = nurse.countShiftType(ShiftType.night) * 12;

      row.addAll([
        mHrs,
        eHrs,
        nHrs,
        (mHrs + eHrs + nHrs)
      ]);
      ws.appendRow(row);
    }

    // Daily Totals
    List<dynamic> totalM = ["Total M", ""];
    List<dynamic> totalE = ["Total E", ""];
    List<dynamic> totalN = ["Total N", ""];

    for (int d = 1; d <= 31; d++) {
      int mCount = 0;
      int eCount = 0;
      int nCount = 0;
      for (var nurse in nurses) {
        var shift = nurse.getShift(d);
        if (shift == ShiftType.morning) mCount++;
        if (shift == ShiftType.evening) eCount++;
        if (shift == ShiftType.night) nCount++;
      }
      totalM.add(mCount);
      totalE.add(eCount);
      totalN.add(nCount);
    }

    ws.appendRow([]); // Empty row
    ws.appendRow(totalM);
    ws.appendRow(totalE);
    ws.appendRow(totalN);

    // Style the totals roughly (Excel package has limited styling unless Pro, but we can do bold)
    var boldStyle = CellStyle(bold: true);
    for (int r = ws.maxRows - 3; r < ws.maxRows; r++) {
      for (int c = 0; c < ws.maxCols; c++) {
        var cell = ws.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.cellStyle = boldStyle;
      }
    }

    // Official Signatures
    ws.appendRow([]);
    ws.appendRow([]);
    ws.appendRow(["", "", "", "Date: ___________________"]);
    ws.appendRow([]);
    ws.appendRow(["", "", "", "Head nurse signature: ___________________"]);

    var fileBytes = excel.save();
    if (fileBytes != null) {
      return Uint8List.fromList(fileBytes);
    }
    return null;
  }
}
