# دليل تشغيل المشروع لفريق العمل (Team Setup Guide)

الدليل ده بيوضح إزاي أي حد في التيم ينزّل المشروع والداتا ويشغّل الـ pipeline كله (Bronze → Silver → Gold)
على جهازه، سواء ماك أو ويندوز. التصميم الحالي: داتا حقيقية بس، العلاقات بين الداتا متعرّفة الأول،
وجدول Gold واحد (`gold.av_readiness_region_month`). التفاصيل في
[05_relations_and_lineage.md](05_relations_and_lineage.md).

---

## 1. المتطلبات

| | ماك | ويندوز |
|---|---|---|
| SQL Server | SQL Server 2022 في Docker (container اسمه `sql2022`) | SQL Server محلي (Express أو Developer) |
| أداة الاستعلام | VS Code + mssql extension، أو DataGrip | SSMS أو VS Code |
| sqlcmd | موجود جوه الـ container | SQL Server command-line tools (sqlcmd) |
| Python | Python 3.10+ | Python 3.10+ (على الـ PATH) |
| Git | ✓ | ✓ |

الـ scripts بتعمل `.venv` وتنزّل `openpyxl` و`pandas` و`numpy` لوحدها أول مرة.

---

## 2. الخطوات

### الخطوة 1: نزّل الريبو
```bash
git clone https://github.com/farahatsaafan/AV-Ready-Saudi.git
cd AV-Ready-Saudi
```

### الخطوة 2: نزّل الداتا
* من Google Drive: [New Data](https://drive.google.com/drive/folders/1hmh-0XqcQ9MZ5juEkdRgR7CMA9GsERj3)
  ← الملف `AV-Ready-Saudi_Data_raw.zip` (حوالي 36MB).
* فكّ الضغط **جوه فولدر المشروع نفسه**. الـ zip فيه المسارات جاهزة، فالشكل النهائي هيبقى:
  ```text
  AV-Ready-Saudi/Data/raw/noaa_global_hourly/2021 ... 2025/
  AV-Ready-Saudi/Data/raw/gastat/
  AV-Ready-Saudi/Data/raw/ca_dmv_disengagements/
  AV-Ready-Saudi/Data/raw/ca_dmv_mileage/
  AV-Ready-Saudi/Data/raw/nhtsa_sgo/
  ```
* الـ zip فيه بالظبط الملفات اللي الـ pipeline بيقراها (114 ملف). تفاصيل كل مصدر في
  [DATA_SOURCES.md](DATA_SOURCES.md).

### الخطوة 3: شغّل الـ pipeline

**ماك** (Docker Desktop شغال والـ container `sql2022` شغال):
```bash
SA_PASSWORD='باسورد الـ sa بتاعك' bash run_pipeline_mac.sh
```

**ويندوز** (PowerShell من فولدر المشروع):
```powershell
powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1
# لو الـ instance مش SQLEXPRESS:
powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1 -ServerInstance "localhost"
```
ملاحظة ويندوز: `BULK INSERT` بيقرا الملفات بحساب خدمة SQL Server، فلازم الحساب ده يقدر يقرا فولدر
`Data\landing` (أو مرّر مسار تاني بـ `-LandingPath`).

الـ script بيعمل بالترتيب:
1. `python/00_land_raw.py`: بيحوّل `Data/raw` لـ `Data/landing/*.tsv` (شكل الملف بس، القيم زي ما هي).
2. `sql/00_init.sql` → `01_bronze.sql` → `02_silver.sql` → `03_gold.sql` مع الـ load procedures بتاعتهم.
3. `sql/quality/*.sql`: validation وreconciliation وchecks الـ Gold ونسب الداتا وrollback demo.
4. `python/02_reference_gold.py`: بناء مستقل بـ pandas للمقارنة مع نتيجة SQL.

لازم كل الـ checks تطلع **PASS**.

### لو عندك database قديمة من التصميم القديم
مش محتاج تعمل حاجة. `sql/00_init.sql` بيمسح جداول الـ Star Schema القديمة وobjects الـ semantic / ml
وجدول `audit.load_log` القديم لوحده، وبعدين يكمل عادي.

---

## 3. الاتصال بالـ database

* ماك: server `localhost,1433`، user `sa`، database `av_ready_saudi_dw`.
* ويندوز: server `.\SQLEXPRESS` (أو اسم الـ instance بتاعك)، Windows Authentication.
* جدول النتيجة: `gold.av_readiness_region_month` (13 منطقة × 60 شهر = 780 صف).

---

## 4. قواعد Git

1. اسحب آخر تحديثات قبل ما تشتغل: `git pull origin main`
2. اشتغل على البرانش بتاعك (مثلاً `dev-<اسمك>`)، وافتح Pull Request على `main`.
3. رسائل commit واضحة، مثال: `fix(silver): ...` أو `docs: ...`
4. **ممنوع ترفع أي داتا على GitHub** (فولدر `Data/` متعمله ignore). الداتا مكانها الدرايف بس.
