# Egyptian Nursing Shift Scheduler

An automated, safety-first, mathematically equitable shift scheduling application built with Flutter, designed explicitly to comply with the official Egyptian Nursing manual constraints.

## Overview
This application automates the complex task of generating monthly schedules for hospital nursing units. It replaces manual, error-prone spreadsheets with an algorithm that rigorously enforces medical safety rules, labor laws, and absolute fairness among staff.

It cross-compiles to a Windows executable (for administrative office use) and an Android APK (for mobile access).

## Features & "Red Line" Safety Rules
The scheduler implements strict algorithmic constraints:

1. **The "Never Alone" Skill Mix Rule**: A Technical Nurse (TN) will *never* be assigned to a shift without at least one Professional/Registered Nurse (PN) present to supervise.
2. **Total Weekly Clamping (144-162 Hours)**: The generator mathematically forces all rotating staff to land between 144 and 162 total hours for the month, eliminating burnout and underutilization. 
3. **Perfect 31-Day Staggered Cyclic Array**: For 31-day months requiring 144 hours and exactly 4 night shifts, the system bypasses random generation to apply a perfectly equitable cyclic array (`N, O, M, M, E, E, O, N...`), ensuring flawless fairness between every PN and TN. It applies a rolling offset to ensure weekends are distributed fairly over the year.
4. **No Double Shifts**: The internal state machine explicitly forbids illegal double shifts (e.g., a Morning immediately followed by an Evening).
5. **Strict Post-Night Off**: A "Sleep Day" is mathematically guaranteed after every Night shift to allow biological clocks to reset.
6. **Leadership Isolation**: Head Nurses and Assistants are scheduled independently from the primary rotation array, working exclusively Morning shifts, guaranteeing a 1-day spacing between their days off.
7. **Dynamic Shift Ratios**: Targets the required distributions (45% Morning, 37% Evening, 18% Night), adjusting dynamically for lighter Friday morning quotas.
8. **Holiday Integration**: Automatically fetches and applies the official 2026 Egyptian holiday calendar. Enforces "Day 2 Off" relief for nurses working the start of multi-day holidays like Eid.
9. **Legally Binding Excel Export**: Outputs clean `.xlsx` schedules complete with calculating totals, fairness tracking columns (Fri/Hol), and official signature footers (`Date:` and `Head nurse signature:`).

## Tech Stack
- **Framework**: Flutter (Dart)
- **UI Design**: Material 3 (Glassmorphism styling, animated fluid transitions)
- **Export**: `excel` package (for .xlsx generation), `share_plus` (for cross-platform file saving and sharing)
- **CI/CD**: GitHub Actions (Automated release builds for Android APK and Windows EXE)

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK

### Running Locally
1. Clone the repository: `git clone https://github.com/bbnhd2222-hash/shift-scheduler.git`
2. Navigate to the project directory: `cd shift-scheduler`
3. Install dependencies: `flutter pub get`
4. Run the app: `flutter run` (Specify `-d windows`, `-d android`, or `-d chrome`)

### Building for Production
- **Windows**: `flutter build windows` (Executable found in `build\windows\x64\runner\Release\`)
- **Android**: `flutter build apk` (APK found in `build\app\outputs\flutter-apk\app-release.apk`)

Automated builds are also available via the repository's GitHub Actions "Releases" page.

## Usage
1. Open the application.
2. Select the target **Year** and **Month**.
3. Input the number of Professional Nurses (**PN**), Technical Nurses (**TN**), Head Nurses (**HN**), and Assistants (**Asst**).
4. Set the desired **Target Hours** (e.g., 144, 150, 156, 162) and **Night Shifts per Nurse** (e.g., 4).
5. Click **Generate Roster**. The algorithm will compute the schedule.
6. Review the visual grid. Ensure the equity meters (Fri, Hol counts) align.
7. Click **Export to Excel** to save the legally binding document for printing and signature.
