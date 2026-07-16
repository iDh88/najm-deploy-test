"""Offline pdfplumber shim — satisfies import; opening a PDF raises."""
def open(*a, **k):
    raise RuntimeError("offline shim: pdfplumber.open unavailable")
