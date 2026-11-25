"""
AV-Ready-Saudi - Step 0: land the raw source files as load-ready TSV files.

Why this step exists
--------------------
SQL Server BULK INSERT needs one fixed column layout per table, but our raw
sources are not shaped that way:
  * NOAA Global Hourly CSVs carry a different set of optional columns per station
  * GASTAT tables are Excel workbooks (BULK INSERT cannot read .xlsx)
  * CA DMV mileage files name their month columns differently every year
  * the two NHTSA SGO files have different column sets (137 vs 116 columns)

This script ONLY changes the container format. Every value is copied verbatim
as text: no trimming, no type conversion, no row or column is dropped.
  * columns that every file shares become real Bronze columns
  * all remaining columns of a row are kept, with their original header names,
    in one JSON text column (extra_json / months_json / row_json)
  * Excel cells are written one row per cell (file, sheet, row, column, value);
    formulas such as =SUM(B8:B20) are kept as the formula text

Output: Data/landing/*.tsv  (UTF-16LE with BOM, tab-separated, CRLF line ends, header row).
Tabs and line breaks inside plain-text values are written as the two-character
sequences \\t, \\r, \\n so a value can never break the TSV layout.

Usage (from the project folder):  python3 python/00_land_raw.py
Standard library + openpyxl only.
"""
from __future__ import annotations

import csv
import hashlib
import json
import sys
from pathlib import Path

# sys.maxsize overflows the C long on 64-bit Windows (Python <= 3.12)
csv.field_size_limit(min(sys.maxsize, 2**31 - 1))

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "Data" / "raw"
OUT = ROOT / "Data" / "landing"

NOAA_CORE = ["STATION", "DATE", "SOURCE", "LATITUDE", "LONGITUDE", "ELEVATION", "NAME",
             "REPORT_TYPE", "CALL_SIGN", "QUALITY_CONTROL", "WND", "CIG", "VIS", "TMP",
             "DEW", "SLP", "AA1", "MW1", "AW1", "AU1"]
DMV_DIS_COLS = ["manufacturer", "permit_number", "date_raw", "vin", "capable_without_driver",
                "driver_present", "initiated_by", "location", "description"]
MILEAGE_CORE = ["manufacturer", "permit_number", "vin", "annual_disengagements"]
NHTSA_CORE = ["Report ID", "Report Version", "Reporting Entity", "Make", "Model", "Model Year",
              "State", "City", "Incident Date", "Incident Time (24:00)", "Roadway Type",
              "Posted Speed Limit (MPH)", "Lighting"]


def esc(value) -> str:
    """Make a value safe for one TSV field without changing its content."""
    if value is None:
        return ""
    s = str(value)
    # Only the three layout characters are escaped. JSON text never contains
    # them raw (json.dumps writes them as \t \r \n), so JSON stays valid as is.
    return s.replace("\t", "\\t").replace("\r", "\\r").replace("\n", "\\n")


def jdump(d: dict) -> str:
    return json.dumps(d, ensure_ascii=False, separators=(",", ":"))


class Writer:
    def __init__(self, name: str, header: list[str]):
        OUT.mkdir(parents=True, exist_ok=True)
        self.path = OUT / name
        # UTF-16LE + CRLF: SQL Server on Linux cannot read UTF-8 with CODEPAGE, but it reads
        # UTF-16 natively (BULK INSERT ... DATAFILETYPE = 'widechar', ROWTERMINATOR = '\n' = CRLF).
        # "utf-16" writes the byte-order mark (FF FE) that BULK INSERT needs to accept widechar.
        self.fh = open(self.path, "w", encoding="utf-16", newline="\r\n")
        self.ncol = len(header)
        self.rows = 0
        # last column "row_end" = "." on every row: whatever line-end convention BULK INSERT
        # applies (CRLF on Windows, LF on Linux), a leftover CR can only reach this marker.
        self.fh.write("\t".join(header + ["row_end"]) + "\n")

    def row(self, values: list) -> None:
        assert len(values) == self.ncol, (self.path.name, len(values), self.ncol)
        self.fh.write("\t".join([esc(v) for v in values] + ["."]) + "\n")
        self.rows += 1

    def close(self) -> int:
        self.fh.close()
        return self.rows


def rel(p: Path) -> str:
    return p.relative_to(RAW).as_posix()


def read_csv(path: Path) -> list[list[str]]:
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as fh:
        return list(csv.reader(fh))


def land_noaa() -> int:
    w = Writer("noaa_hourly.tsv", ["source_file", "source_row_num"] + NOAA_CORE + ["extra_json"])
    for f in sorted((RAW / "noaa_global_hourly").glob("*/*.csv")):
        if f.name == "MANIFEST.csv":
            continue
        rows = read_csv(f)
        header = rows[0]
        for i, r in enumerate(rows[1:], start=2):
            if not any(r):
                continue
            rec = dict(zip(header, r))
            extra = {k: v for k, v in rec.items() if k not in NOAA_CORE and v != ""}
            w.row([rel(f), i] + [rec.get(c, "") for c in NOAA_CORE] + [jdump(extra)])
    return w.close()


def land_gastat() -> int:
    import openpyxl
    w = Writer("gastat_cells.tsv", ["source_file", "sheet_name", "row_num", "col_num", "cell_value"])
    for f in sorted((RAW / "gastat").glob("*.xlsx")):
        wb = openpyxl.load_workbook(f, read_only=True, data_only=False)
        for ws in wb.worksheets:
            for r_idx, row in enumerate(ws.iter_rows(values_only=True), start=1):
                for c_idx, val in enumerate(row, start=1):
                    if val is None or (isinstance(val, str) and val == ""):
                        continue
                    w.row([rel(f), ws.title, r_idx, c_idx, val])
        wb.close()
    return w.close()


def land_dmv_disengagements() -> int:
    w = Writer("dmv_disengagements.tsv", ["source_file", "source_row_num"] + DMV_DIS_COLS + ["extra_json"])
    for f in sorted((RAW / "ca_dmv_disengagements").glob("*.csv")):
        rows = read_csv(f)
        header = rows[0]
        for i, r in enumerate(rows[1:], start=2):
            if not any(c.strip() for c in r):
                continue  # fully blank padding line in the source file
            core = (r + [""] * 9)[:9]
            extra = {(header[j] if j < len(header) and header[j] else f"col{j+1}"): r[j]
                     for j in range(9, len(r)) if r[j] != ""}
            w.row([rel(f), i] + core + [jdump(extra)])
    return w.close()


def land_dmv_mileage() -> int:
    w = Writer("dmv_mileage.tsv", ["source_file", "source_row_num"] + MILEAGE_CORE + ["months_json"])
    for f in sorted((RAW / "ca_dmv_mileage").glob("*.csv")):
        rows = read_csv(f)
        header = rows[0]
        for i, r in enumerate(rows[1:], start=2):
            if not any(c.strip() for c in r):
                continue
            core = (r + [""] * 4)[:4]
            months = {(header[j] if j < len(header) and header[j] else f"col{j+1}"): r[j]
                      for j in range(4, len(r)) if r[j] != ""}
            w.row([rel(f), i] + core + [jdump(months)])
    return w.close()


def land_nhtsa() -> int:
    w = Writer("nhtsa_sgo_ads.tsv", ["source_file", "source_row_num"] + NHTSA_CORE + ["row_json"])
    for f in sorted((RAW / "nhtsa_sgo").glob("*.csv")):
        rows = read_csv(f)
        header = rows[0]
        for i, r in enumerate(rows[1:], start=2):
            if not any(r):
                continue
            rec = dict(zip(header, r))
            w.row([rel(f), i] + [rec.get(c, "") for c in NHTSA_CORE] + [jdump(rec)])
    return w.close()


def main() -> None:
    steps = [("noaa_hourly.tsv", land_noaa), ("gastat_cells.tsv", land_gastat),
             ("dmv_disengagements.tsv", land_dmv_disengagements),
             ("dmv_mileage.tsv", land_dmv_mileage), ("nhtsa_sgo_ads.tsv", land_nhtsa)]
    manifest = []
    for name, fn in steps:
        n = fn()
        digest = hashlib.sha256((OUT / name).read_bytes()).hexdigest()
        manifest.append((name, n, digest))
        print(f"{name:28s} {n:>9,d} rows")
    with open(OUT / "LANDING_MANIFEST.csv", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("file,rows,sha256\n")
        for name, n, d in manifest:
            fh.write(f"{name},{n},{d}\n")


if __name__ == "__main__":
    main()
