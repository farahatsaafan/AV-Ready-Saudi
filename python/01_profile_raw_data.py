"""
Project: AV-Ready-Saudi
Script: python/01_profile_raw_data.py
Purpose: Reproducible source dataset inventory and profiling (Lecture 2 Slide 35)
"""

import os
import csv
import sys

# Allow large fields (e.g. GeoJSON strings)
# sys.maxsize overflows the C long on 64-bit Windows (Python <= 3.12)
csv.field_size_limit(min(sys.maxsize, 2**31 - 1))

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Data", "raw")

# One folder per source (see docs/DATA_SOURCES.md); folders starting with "_" are not used.
SOURCE_DIRS = sorted(d for d in os.listdir(DATA_DIR)
                     if os.path.isdir(os.path.join(DATA_DIR, d)) and not d.startswith("_"))


def first_csv(folder):
    """Return the first CSV (relative to DATA_DIR) in a source folder, searching subfolders too."""
    for root, _, files in sorted(os.walk(os.path.join(DATA_DIR, folder))):
        for name in sorted(files):
            if name.lower().endswith(".csv"):
                return os.path.relpath(os.path.join(root, name), DATA_DIR)
    return None


def sniff_delimiter(file_path):
    with open(file_path, mode='r', encoding='utf-8-sig', errors='ignore') as f:
        sample = f.read(64 * 1024)
    try:
        return csv.Sniffer().sniff(sample, delimiters=',;\t|').delimiter
    except csv.Error:
        return ','


def profile_csv(file_name, delimiter=None):
    file_path = os.path.join(DATA_DIR, file_name)
    if not os.path.exists(file_path):
        print(f"[MISSING] {file_name} not found at {file_path}")
        return
    if delimiter is None:
        delimiter = sniff_delimiter(file_path)

    print("=" * 60)
    print(f"Profiling Source File: {file_name}")
    print("=" * 60)

    with open(file_path, mode='r', encoding='utf-8-sig', errors='ignore') as f:
        reader = csv.reader(f, delimiter=delimiter)
        try:
            header = next(reader)
        except StopIteration:
            print("File is empty.")
            return

        total_rows = 0
        blank_counts = {col: 0 for col in header}
        distinct_samples = {col: set() for col in header}

        for row in reader:
            total_rows += 1
            for col_name, val in zip(header, row):
                val_clean = val.strip()
                if not val_clean:
                    blank_counts[col_name] += 1
                elif len(distinct_samples[col_name]) < 5:
                    distinct_samples[col_name].add(val_clean)

    print(f"Total Data Rows : {total_rows:,}")
    print(f"Total Columns   : {len(header)}")
    print("\nColumn Quality Breakdown:")
    for col in header:
        blanks = blank_counts[col]
        pct = (blanks / total_rows * 100) if total_rows > 0 else 0
        samples = list(distinct_samples[col])[:3]
        print(f" - {col:<25} | Blanks: {blanks:<6} ({pct:5.2f}%) | Samples: {samples}")
    print("\n")

if __name__ == "__main__":
    print("Starting AV-Ready-Saudi Source File Inventory...\n")
    for folder in SOURCE_DIRS:
        sample = first_csv(folder)
        if sample is None:
            print(f"[SKIP] {folder}: no CSV files (xlsx/pbf sources are read by python/00_land_raw.py)\n")
            continue
        profile_csv(sample)
    print("Source profiling complete.")
