import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/nurse.dart';
import '../models/shift_type.dart';
import '../services/scheduler.dart';
import '../services/exporter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _monthCtrl = TextEditingController(text: "3");
  final TextEditingController _yearCtrl = TextEditingController(text: "2026");
  final TextEditingController _hnCtrl = TextEditingController(text: "1");
  final TextEditingController _asstCtrl = TextEditingController(text: "1");
  final TextEditingController _pnCtrl = TextEditingController(text: "5");
  final TextEditingController _tnCtrl = TextEditingController(text: "2");
  final TextEditingController _hoursCtrl = TextEditingController(text: "160");
  final TextEditingController _nightsCtrl = TextEditingController(text: "4");

  List<Nurse> _schedule = [];
  bool _isGenerating = false;

  void _generate() {
    setState(() { _isGenerating = true; });
    try {
      int year = int.parse(_yearCtrl.text);
      int month = int.parse(_monthCtrl.text);
      
      Map<String, int> staff = {
        'HN': int.parse(_hnCtrl.text),
        'Asst': int.parse(_asstCtrl.text),
        'PN': int.parse(_pnCtrl.text),
        'TN': int.parse(_tnCtrl.text),
      };
      
      List<int> holidays = month == 3 ? [21, 22, 23] : []; // Sample holidays
      
      Scheduler scheduler = Scheduler();
      var result = scheduler.generateSchedule(
        year, month, staff, holidays,
        targetHours: int.parse(_hoursCtrl.text),
        targetNights: int.parse(_nightsCtrl.text),
      );
      
      setState(() {
        _schedule = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Schedule Generated!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isGenerating = false; });
    }
  }

  void _cycleShift(Nurse nurse, int day) {
    ShiftType current = nurse.getShift(day);
    ShiftType next;
    switch (current) {
      case ShiftType.morning: next = ShiftType.evening; break;
      case ShiftType.evening: next = ShiftType.night; break;
      case ShiftType.night: next = ShiftType.off; break;
      case ShiftType.off: next = ShiftType.morning; break;
    }
    setState(() {
      nurse.assignShift(day, next);
    });
  }

  Future<void> _exportExcel() async {
    if (_schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Generate schedule first!"), backgroundColor: Colors.red),
      );
      return;
    }
    
    try {
      int year = int.parse(_yearCtrl.text);
      int month = int.parse(_monthCtrl.text);
      
      Directory tempDir = await getTemporaryDirectory();
      String path = '${tempDir.path}/Schedule_${month}_$year.xlsx';
      
      await Exporter.exportToExcel(_schedule, year, month, path);
      
      await Share.shareXFiles([XFile(path)], text: 'Schedule for $month/$year');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildConfigDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text("Settings", style: Theme.of(context).textTheme.headlineSmall),
            const Divider(),
            Row(
              children: [
                Expanded(child: TextField(controller: _monthCtrl, decoration: const InputDecoration(labelText: "Month"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _yearCtrl, decoration: const InputDecoration(labelText: "Year"))),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Staff Counts", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: TextField(controller: _hnCtrl, decoration: const InputDecoration(labelText: "HN"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _asstCtrl, decoration: const InputDecoration(labelText: "Asst"))),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _pnCtrl, decoration: const InputDecoration(labelText: "PN"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _tnCtrl, decoration: const InputDecoration(labelText: "TN"))),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Targets", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: TextField(controller: _hoursCtrl, decoration: const InputDecoration(labelText: "Target Hrs"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _nightsCtrl, decoration: const InputDecoration(labelText: "Target N"))),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generate,
              icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.autorenew),
              label: const Text("Generate Schedule"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.download),
              label: const Text("Export Excel & Share"),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Dev: Abdelrahman Shaer Deghady", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Color _getShiftColor(ShiftType shift) {
    switch(shift) {
      case ShiftType.morning: return Colors.green.shade700;
      case ShiftType.evening: return Colors.blue.shade700;
      case ShiftType.night: return Colors.red.shade900;
      case ShiftType.off: return Colors.grey.shade800;
    }
  }

  Widget _buildDataTable() {
    if (_schedule.isEmpty) {
      return const Center(child: Text("Configure settings and click Generate", style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    int year = int.tryParse(_yearCtrl.text) ?? 2026;
    int month = int.tryParse(_monthCtrl.text) ?? 3;
    int daysInMonth = Scheduler().getMonthDays(year, month);
    List<int> days = List.generate(daysInMonth, (i) => i + 1);

    // Calculate Daily Totals
    Map<int, int> tm = {};
    Map<int, int> te = {};
    Map<int, int> tn = {};
    Map<int, int> tStaff = {};

    for (int d in days) {
      int m = 0, e = 0, n = 0, staff = 0;
      for (var nurse in _schedule) {
        var s = nurse.getShift(d);
        if (s == ShiftType.morning) m++;
        if (s == ShiftType.evening) e++;
        if (s == ShiftType.night) n++;
        if (nurse.role != "HN" && nurse.role != "Asst" && s != ShiftType.off) staff++;
      }
      tm[d] = m;
      te[d] = e;
      tn[d] = n;
      tStaff[d] = staff;
    }

    // Build the grid inside constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columns: [
                const DataColumn(label: Text("Name")),
                for (int d in days) DataColumn(label: Text("$d")),
                const DataColumn(label: Text("M Hrs")),
                const DataColumn(label: Text("E Hrs")),
                const DataColumn(label: Text("N Hrs")),
                const DataColumn(label: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                ..._schedule.map((nurse) {
                  int mHrs = nurse.countShiftType(ShiftType.morning) * 6;
                  int eHrs = nurse.countShiftType(ShiftType.evening) * 6;
                  int nHrs = nurse.countShiftType(ShiftType.night) * 12;

                  return DataRow(
                    cells: [
                      DataCell(Text(nurse.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      for (int d in days) 
                        DataCell(
                          InkWell(
                            onTap: () => _cycleShift(nurse, d),
                            child: Container(
                              width: 35,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _getShiftColor(nurse.getShift(d)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                nurse.getShift(d) == ShiftType.off ? "-" : nurse.getShift(d).value,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      DataCell(Text("$mHrs")),
                      DataCell(Text("$eHrs")),
                      DataCell(Text("$nHrs")),
                      DataCell(Text("${mHrs + eHrs + nHrs}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  );
                }),
                // Footer Rows
                _buildFooterRow("Total M", tm, days, Colors.green.shade900),
                _buildFooterRow("Total E", te, days, Colors.blue.shade900),
                _buildFooterRow("Total N", tn, days, Colors.red.shade900),
                _buildFooterRow("Staff", tStaff, days, Colors.grey.shade700),
              ],
            ),
          ),
        );
      }
    );
  }

  DataRow _buildFooterRow(String label, Map<int, int> data, List<int> days, Color color) {
    return DataRow(
      color: WidgetStateProperty.all(Colors.black12),
      cells: [
        DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        for (int d in days)
          DataCell(
            Container(
              width: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text("${data[d]}", style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          ),
        const DataCell(Text("")),
        const DataCell(Text("")),
        const DataCell(Text("")),
        const DataCell(Text("")),
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    // If screen is wide, show drawer as sidebar
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text("Shift Scheduler"),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      drawer: isDesktop ? null : _buildConfigDrawer(),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 300,
              child: _buildConfigDrawer(),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildDataTable(),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
