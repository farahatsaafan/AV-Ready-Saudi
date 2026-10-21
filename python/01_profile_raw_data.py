"""
Project: AV-Ready-Saudi
Script: python/01_profile_raw_data.py
Purpose: Reproducible source dataset inventory and profiling (Lecture 2 Slide 35)
"""

import os
import csv
import sys

# Allow large fields (e.g. GeoJSON strings)
csv.field_size_limit(sys.maxsize)

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Data")

def profile_csv(file_name, delimiter=','):
    file_path = os.path.join(DATA_DIR, file_name)
    if not os.path.exists(file_path):
        print(f"[MISSING] {file_name} not found at {file_path}")
        return

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
    profile_csv("weather-sa-2017-2019-clean.csv", delimiter=',')
    profile_csv("saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008.csv", delimiter=';')
    profile_csv(os.path.join("A2RL_IAC_prediction_annotations", "a2rl_raw.csv"), delimiter=',')
    print("Source profiling complete.")
