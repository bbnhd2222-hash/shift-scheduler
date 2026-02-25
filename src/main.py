import flet as ft
from datetime import datetime
import os
import sys

# Ensure we can import from the same directory even if run from root
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from scheduler import Scheduler
from exporter import Exporter
from models import ShiftType, Nurse

def main(page: ft.Page):
    page.title = "Egyptian Nursing Shift Scheduler"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 10
    
    scheduler = Scheduler()
    
    state_schedule = []
    state_year = 2026
    state_month = 3
    
    # --- Sidebar Controls ---
    month_dropdown = ft.Dropdown(
        label="Month",
        options=[ft.dropdown.Option(str(i)) for i in range(1, 13)],
        value="3",
        dense=True,
        expand=True
    )
    year_field = ft.TextField(label="Year", value="2026", dense=True, expand=True)
    
    hn_field = ft.TextField(label="Head Nurses", value="1", dense=True, expand=True)
    asst_field = ft.TextField(label="Assistants", value="1", dense=True, expand=True)
    pn_field = ft.TextField(label="Prof. Nurses", value="5", dense=True, expand=True)
    tn_field = ft.TextField(label="Tech. Nurses", value="2", dense=True, expand=True)
    
    hours_field = ft.TextField(label="Target Hrs", value="160", dense=True, expand=True)
    nights_field = ft.TextField(label="Target Nights", value="4", dense=True, expand=True)
    
    def show_snack(message, color=ft.colors.GREEN):
        page.snack_bar = ft.SnackBar(ft.Text(message), bgcolor=color)
        page.snack_bar.open = True
        page.update()

    table_container = ft.Column(scroll=ft.ScrollMode.ALWAYS, expand=True)
    
    def on_generate(e):
        nonlocal state_schedule, state_year, state_month
        try:
            state_year = int(year_field.value)
            state_month = int(month_dropdown.value)
            staff = {
                'HN': int(hn_field.value),
                'Asst': int(asst_field.value),
                'PN': int(pn_field.value),
                'TN': int(tn_field.value)
            }
            holidays = [21, 22, 23] if state_month == 3 else []
            t_hours = int(hours_field.value)
            t_nights = int(nights_field.value)
            
            state_schedule = scheduler.generate_schedule(
                state_year, state_month, staff, holidays, t_hours, t_nights
            )
            render_table()
            show_snack("Schedule Generated Successfully!")
        except Exception as ex:
            show_snack(f"Error: {ex}", ft.colors.RED)

    def on_export(e):
        if not state_schedule:
            show_snack("Generate schedule first!", ft.colors.RED)
            return

        def save_file_result(e: ft.FilePickerResultEvent):
            if e.path:
                try:
                    path = e.path if e.path.endswith('.xlsx') else e.path + '.xlsx'
                    Exporter.export_to_excel(state_schedule, state_year, state_month, path)
                    show_snack(f"Exported to {path}")
                except Exception as ex:
                    show_snack(f"Export Error: {ex}", ft.colors.RED)
        
        file_picker.save_file(
            dialog_title="Save as Excel",
            file_name=f"Schedule_{state_month}_{state_year}.xlsx",
            allowed_extensions=["xlsx"]
        )

    file_picker = ft.FilePicker(on_result=save_file_result)
    page.overlay.append(file_picker)

    # Rendering the Table
    nurse_totals = {}
    daily_totals = {"M": {}, "E": {}, "N": {}, "Staff": {}}

    def update_totals():
        for nurse in state_schedule:
            m_c = nurse.count_shift_type(ShiftType.MORNING)
            e_c = nurse.count_shift_type(ShiftType.EVENING)
            n_c = nurse.count_shift_type(ShiftType.NIGHT)
            if nurse.name in nurse_totals:
                nurse_totals[nurse.name]["M"].value = str(m_c * 6)
                nurse_totals[nurse.name]["E"].value = str(e_c * 6)
                nurse_totals[nurse.name]["N"].value = str(n_c * 12)
                nurse_totals[nurse.name]["Total"].value = str((m_c + e_c)*6 + n_c*12)
        
        for d in range(1, 32):
            dm = de = dn = d_staff = 0
            for nurse in state_schedule:
                s = nurse.get_shift(d)
                if s == ShiftType.MORNING: dm += 1
                elif s == ShiftType.EVENING: de += 1
                elif s == ShiftType.NIGHT: dn += 1
                if nurse.role not in ("HN", "Asst") and s != ShiftType.OFF:
                    d_staff += 1
            if d in daily_totals["M"]:
                daily_totals["M"][d].value = str(dm)
                daily_totals["E"][d].value = str(de)
                daily_totals["N"][d].value = str(dn)
                daily_totals["Staff"][d].value = str(d_staff)
        page.update()

    def create_cell(nurse, day):
        shift = nurse.get_shift(day)
        
        colors = {
            ShiftType.MORNING: ft.colors.GREEN_700,
            ShiftType.EVENING: ft.colors.BLUE_700,
            ShiftType.NIGHT: ft.colors.RED_900,
            ShiftType.OFF: ft.colors.GREY_800
        }
        
        text_ctrl = ft.Text(shift.value if shift != ShiftType.OFF else "-", weight=ft.FontWeight.BOLD)
        
        def on_click(e):
            nonlocal shift
            next_map = {
                ShiftType.MORNING: ShiftType.EVENING,
                ShiftType.EVENING: ShiftType.NIGHT,
                ShiftType.NIGHT: ShiftType.OFF,
                ShiftType.OFF: ShiftType.MORNING
            }
            new_shift = next_map[shift]
            nurse.assign_shift(day, new_shift)
            shift = new_shift
            text_ctrl.value = shift.value if shift != ShiftType.OFF else "-"
            e.control.bgcolor = colors[shift]
            update_totals()

        return ft.Container(
            content=text_ctrl,
            width=35,
            height=35,
            alignment=ft.alignment.center,
            bgcolor=colors[shift],
            border_radius=4,
            on_click=on_click,
            ink=True,
            tooltip=f"{nurse.name} (Day {day})"
        )

    def render_table():
        table_container.controls.clear()
        nurse_totals.clear()
        for k in daily_totals:
            daily_totals[k].clear()
            
        header_row = ft.Row(spacing=2)
        header_row.controls.append(ft.Container(width=100, content=ft.Text("Name", weight="bold")))
        for d in range(1, 32):
            header_row.controls.append(ft.Container(width=35, alignment=ft.alignment.center, content=ft.Text(str(d), weight="bold")))
            
        header_row.controls.extend([
            ft.Container(width=40, content=ft.Text("M Hrs", size=10, weight="bold")),
            ft.Container(width=40, content=ft.Text("E Hrs", size=10, weight="bold")),
            ft.Container(width=40, content=ft.Text("N Hrs", size=10, weight="bold")),
            ft.Container(width=50, content=ft.Text("Total", size=12, weight="bold")),
        ])
        table_container.controls.append(header_row)
        
        for nurse in state_schedule:
            row = ft.Row(spacing=2)
            row.controls.append(ft.Container(width=100, content=ft.Text(nurse.name, size=12)))
            
            for d in range(1, 32):
                row.controls.append(create_cell(nurse, d))
                
            m_txt = ft.Text("0", size=12)
            e_txt = ft.Text("0", size=12)
            n_txt = ft.Text("0", size=12)
            tot_txt = ft.Text("0", size=12, weight="bold")
            
            nurse_totals[nurse.name] = {"M": m_txt, "E": e_txt, "N": n_txt, "Total": tot_txt}
            
            row.controls.extend([
                ft.Container(width=40, content=m_txt),
                ft.Container(width=40, content=e_txt),
                ft.Container(width=40, content=n_txt),
                ft.Container(width=50, content=tot_txt),
            ])
            table_container.controls.append(row)
            
        table_container.controls.append(ft.Divider())
        
        def add_footer_row(label, key, color=None):
            row = ft.Row(spacing=2)
            row.controls.append(ft.Container(width=100, alignment=ft.alignment.center_right, content=ft.Text(label, weight="bold", size=11)))
            for d in range(1, 32):
                txt = ft.Text("0", size=11, color="white")
                daily_totals[key][d] = txt
                cnt = ft.Container(width=35, height=25, alignment=ft.alignment.center, bgcolor=color or ft.colors.GREY_800, border_radius=3, content=txt)
                row.controls.append(cnt)
            table_container.controls.append(row)

        add_footer_row("Total M:", "M", ft.colors.GREEN_900)
        add_footer_row("Total E:", "E", ft.colors.BLUE_900)
        add_footer_row("Total N:", "N", ft.colors.RED_900)
        add_footer_row("Staff (Ex. HN):", "Staff", ft.colors.GREY_700)
        
        update_totals()

    # --- Layout ---
    sidebar = ft.Container(
        padding=15,
        bgcolor=ft.colors.SURFACE_VARIANT,
        border_radius=10,
        content=ft.Column(
            scroll=ft.ScrollMode.AUTO,
            controls=[
                ft.Text("Shift Scheduler", size=24, weight="bold", color=ft.colors.PRIMARY),
                ft.Divider(),
                ft.Row([month_dropdown, year_field]),
                ft.Text("Staff Counts", weight="bold"),
                ft.Row([hn_field, asst_field]),
                ft.Row([pn_field, tn_field]),
                ft.Text("Targets", weight="bold"),
                ft.Row([hours_field, nights_field]),
                ft.Divider(),
                ft.ElevatedButton("Generate Schedule", on_click=on_generate, icon=ft.icons.AUTORENEW),
                ft.FilledButton("Export to Excel", on_click=on_export, icon=ft.icons.DOWNLOAD, style=ft.ButtonStyle(bgcolor=ft.colors.GREEN_700)),
                ft.Container(height=20),
                ft.Text("Dev: Abdelrahman Shaer Deghady", size=12, italic=True, color=ft.colors.ON_SURFACE_VARIANT)
            ]
        )
    )

    main_content = ft.Container(
        padding=10,
        content=ft.Column([
            ft.Text("Schedule Preview (Click cells to manually change)", size=18, weight="bold"),
            ft.Row([table_container], scroll=ft.ScrollMode.ALWAYS, expand=True)
        ], expand=True)
    )

    page.add(
        ft.ResponsiveRow(
            controls=[
                ft.Column([sidebar], col={"xs": 12, "md": 4, "lg": 3}),
                ft.Column([main_content], col={"xs": 12, "md": 8, "lg": 9}, expand=True),
            ],
            expand=True
        )
    )

if __name__ == "__main__":
    ft.app(target=main)
