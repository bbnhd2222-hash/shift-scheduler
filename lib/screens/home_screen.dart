import 'package:flutter/material.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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
  
  // Keep track of cells being pressed for bounce animation
  Map<String, bool> _pressedCells = {};

  List<int> _get2026Holidays(int month) {
    switch (month) {
      case 1: return [1, 7, 29];
      case 2: return [19];
      case 3: return [20, 21, 22];
      case 4: return [13, 25];
      case 5: return [1, 3, 26, 27, 28, 29];
      case 6: return [16, 30];
      case 7: return [23];
      case 8: return [26];
      case 10: return [6];
      default: return [];
    }
  }

  void _generate() async {
    setState(() { _isGenerating = true; });
    // Add a tiny delay to allow the loading spinner to show up smoothly
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      int year = int.parse(_yearCtrl.text);
      int month = int.parse(_monthCtrl.text);
      
      Map<String, int> staff = {
        'HN': int.parse(_hnCtrl.text),
        'Asst': int.parse(_asstCtrl.text),
        'PN': int.parse(_pnCtrl.text),
        'TN': int.parse(_tnCtrl.text),
      };
      
      List<int> holidays = year == 2026 ? _get2026Holidays(month) : [];
      
      Scheduler scheduler = Scheduler();
      var result = scheduler.generateSchedule(
        year, month, staff, holidays,
        targetHours: int.parse(_hoursCtrl.text),
        targetNights: int.parse(_nightsCtrl.text),
      );
      
      setState(() {
        _schedule = result;
      });
      _showSnack("✨ Schedule Generated Successfully ✨", Colors.greenAccent.shade700);
    } catch (e) {
      _showSnack("Error: $e", Colors.redAccent);
    } finally {
      setState(() { _isGenerating = false; });
    }
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
      _showSnack("Generate a schedule first!", Colors.orangeAccent);
      return;
    }
    
    try {
      int year = int.parse(_yearCtrl.text);
      int month = int.parse(_monthCtrl.text);
      
      var bytes = await Exporter.exportToExcel(_schedule, year, month);
      
      if (bytes != null) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              name: 'Schedule_${month}_$year.xlsx',
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            )
          ], 
          text: 'Schedule for $month/$year',
        );
      } else {
         _showSnack("Export Error: Could not generate excel", Colors.redAccent);
      }
      
    } catch (e) {
      _showSnack("Export Error: $e", Colors.redAccent);
    }
  }

  Widget _buildConfigDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E2C),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Row(
              children: [
                const Icon(Icons.settings_suggest, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 12),
                Text("Setup", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 24),
            _buildGlassField("Month", _monthCtrl, Icons.calendar_month),
            const SizedBox(height: 12),
            _buildGlassField("Year", _yearCtrl, Icons.calendar_today),
            const SizedBox(height: 24),
            const Text("STAFF COUNTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildGlassField("HN", _hnCtrl, null)),
                const SizedBox(width: 8),
                Expanded(child: _buildGlassField("Asst", _asstCtrl, null)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildGlassField("PN", _pnCtrl, null)),
                const SizedBox(width: 8),
                Expanded(child: _buildGlassField("TN", _tnCtrl, null)),
              ],
            ),
            const SizedBox(height: 24),
            const Text("TARGETS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildGlassField("Hrs", _hoursCtrl, Icons.access_time)),
                const SizedBox(width: 8),
                Expanded(child: _buildGlassField("Nights", _nightsCtrl, Icons.nightlight_round)),
              ],
            ),
            const SizedBox(height: 32),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))
                ]
              ),
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isGenerating 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("GENERATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _exportExcel,
                icon: const Icon(Icons.share, color: Colors.greenAccent),
                label: const Text("EXPORT EXCEL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.greenAccent, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassField(String label, TextEditingController ctrl, IconData? icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: Colors.white54, size: 18) : null,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Color _getShiftColor(ShiftType shift) {
    switch(shift) {
      case ShiftType.morning: return Colors.amber.shade400;
      case ShiftType.evening: return Colors.deepOrangeAccent;
      case ShiftType.night: return Colors.deepPurpleAccent;
      case ShiftType.off: return const Color(0xFF2C2C3E);
    }
  }
  
  Color _getShiftTextColor(ShiftType shift) {
    if (shift == ShiftType.morning) return Colors.black87;
    if (shift == ShiftType.off) return Colors.white30;
    return Colors.white;
  }

  Widget _buildFluidGrid() {
    if (_schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text("Ready to orchestrate the month.", style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    int year = int.tryParse(_yearCtrl.text) ?? 2026;
    int month = int.tryParse(_monthCtrl.text) ?? 3;
    int daysInMonth = Scheduler().getMonthDays(year, month);
    List<int> days = List.generate(daysInMonth, (i) => i + 1);

    // Calculate Daily Totals
    Map<int, int> tm = {};
    Map<int, int> te = {};
    Map<int, int> tn = {};

    for (int d in days) {
      int m = 0, e = 0, n = 0;
      for (var nurse in _schedule) {
        var s = nurse.getShift(d);
        if (s == ShiftType.morning) m++;
        if (s == ShiftType.evening) e++;
        if (s == ShiftType.night) n++;
      }
      tm[d] = m;
      te[d] = e;
      tn[d] = n;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  _buildHeaderCell("Nurse Name", width: 140),
                  for (int d in days) _buildHeaderCell("$d", width: 44, isWeekend: Scheduler().isFriday(year, month, d) || Scheduler().isSaturday(year, month, d)),
                  _buildHeaderCell("M", width: 36, color: Colors.amber.shade800),
                  _buildHeaderCell("E", width: 36, color: Colors.deepOrange.shade800),
                  _buildHeaderCell("N", width: 36, color: Colors.deepPurple.shade800),
                  _buildHeaderCell("Hol", width: 36, color: Colors.teal.shade700),
                  _buildHeaderCell("Fri", width: 36, color: Colors.indigo.shade700),
                  _buildHeaderCell("Σ", width: 44, color: Colors.blueAccent),
                ],
              ),
              const SizedBox(height: 8),
              
              // Nurse Rows
              ..._schedule.map((nurse) {
                int mHrs = nurse.countShiftType(ShiftType.morning) * 6;
                int eHrs = nurse.countShiftType(ShiftType.evening) * 6;
                int nHrs = nurse.countShiftType(ShiftType.night) * 12;
                int totalHrs = mHrs + eHrs + nHrs;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 140,
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(nurse.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                      ),
                      const SizedBox(width: 4),
                      for (int d in days)
                        _buildInteractiveCell(nurse, d),
                      const SizedBox(width: 4),
                      _buildSummaryCell("$mHrs", width: 36),
                      _buildSummaryCell("$eHrs", width: 36),
                      _buildSummaryCell("$nHrs", width: 36),
                      _buildSummaryCell("${nurse.holidaysWorked}", width: 36),
                      _buildSummaryCell("${nurse.fridaysWorked}", width: 36),
                      _buildSummaryCell("$totalHrs", width: 44, isHighlight: true),
                    ],
                  ),
                );
              }),
              
              const SizedBox(height: 16),
              const Text("DAILY TOTALS", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              
              // Footer Totals
              Row(
                children: [
                  _buildHeaderCell("Morning", width: 140, color: Colors.amber.withOpacity(0.2)),
                  for (int d in days) _buildSummaryCell("${tm[d]}", width: 44, color: Colors.amber.withOpacity(0.2)),
                ]
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildHeaderCell("Evening", width: 140, color: Colors.deepOrange.withOpacity(0.2)),
                  for (int d in days) _buildSummaryCell("${te[d]}", width: 44, color: Colors.deepOrange.withOpacity(0.2)),
                ]
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildHeaderCell("Night", width: 140, color: Colors.deepPurple.withOpacity(0.2)),
                  for (int d in days) _buildSummaryCell("${tn[d]}", width: 44, color: Colors.deepPurple.withOpacity(0.2)),
                ]
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required double width, bool isWeekend = false, Color? color}) {
    return Container(
      width: width,
      height: 40,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? (isWeekend ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: isWeekend ? Colors.redAccent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildSummaryCell(String text, {required double width, bool isHighlight = false, Color? color}) {
    return Container(
      width: width,
      height: 44,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? (isHighlight ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(8),
        border: isHighlight ? Border.all(color: Colors.blueAccent.withOpacity(0.5)) : null,
      ),
      child: Text(text, style: TextStyle(color: isHighlight ? Colors.blueAccent : Colors.white, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildInteractiveCell(Nurse nurse, int day) {
    String cellKey = "${nurse.name}_$day";
    bool isPressed = _pressedCells[cellKey] ?? false;
    ShiftType shift = nurse.getShift(day);
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedCells[cellKey] = true),
      onTapUp: (_) {
        setState(() => _pressedCells[cellKey] = false);
        _cycleShift(nurse, day);
      },
      onTapCancel: () => setState(() => _pressedCells[cellKey] = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 4),
        transform: isPressed ? (Matrix4.identity()..scale(0.85, 0.85)..translate(3.0, 3.0)) : Matrix4.identity(),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _getShiftColor(shift),
          borderRadius: BorderRadius.circular(isPressed ? 16 : 8),
          boxShadow: shift != ShiftType.off 
            ? [BoxShadow(color: _getShiftColor(shift).withOpacity(0.4), blurRadius: isPressed ? 2 : 8, offset: isPressed ? const Offset(0,0) : const Offset(0, 3))]
            : [],
        ),
        child: Text(
          shift == ShiftType.off ? "·" : shift.value,
          style: TextStyle(
            color: _getShiftTextColor(shift),
            fontWeight: FontWeight.bold,
            fontSize: shift == ShiftType.off ? 24 : 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: isDesktop ? null : AppBar(
        title: const Text("Shift Scheduler", style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
      ),
      drawer: isDesktop ? null : _buildConfigDrawer(),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 320,
              child: _buildConfigDrawer(),
            ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(isDesktop ? 24.0 : 0),
              decoration: isDesktop ? BoxDecoration(
                color: const Color(0xFF151522),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
              ) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
                child: _buildFluidGrid(),
              ),
            ),
          )
        ],
      ),
    );
  }
}
