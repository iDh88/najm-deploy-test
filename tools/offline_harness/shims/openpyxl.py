"""Offline openpyxl shim — satisfies import; loading a real workbook raises."""
class Workbook:  # minimal placeholder
    pass
def load_workbook(*a, **k):
    raise RuntimeError("offline shim: openpyxl.load_workbook unavailable")
