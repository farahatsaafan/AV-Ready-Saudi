# 📘 الدليل الشامل لمشروع AV-Ready-Saudi — النسخة المحدثة النهائية
### التحضير للمناقشة وتوزيع الأدوار والسيناريو الكامل أمام الدكتور
**تاريخ التحديث:** 16 نوفمبر 2026  
**المشروع:** مستودع بيانات جاهزية الطرق السعودية للمركبات ذاتية القيادة (`AV-Ready-Saudi`)  
**المعمارية المعتمدة:** Medallion Data Architecture (Bronze ➔ Silver ➔ Gold)  
**نسبة البيانات الواقعية الموثقة:** **69.22%** (26,986 صفاً رسمياً وواقعياً من أصل 38,986 صفاً)

---

# 📑 فهرس الدليل
1. [الجزء الأول: شرح المشروع الكامل من الفكرة للطبقة الذهبية (Architecture & Concepts)](#الجزء-الأول-شرح-المشروع-الكامل)
2. [الجزء الثاني: خطوات التجهيز العملي وتشغيل السكريبتات على SSMS لكل لابتوب](#الجزء-الثاني-خطوات-التجهيز-العملي)
3. [الجزء الثالث: تقسيم الشغل والمناقشة على الـ 3 أفراد بالتفصيل والسيناريو المباشر](#الجزء-الثالث-تقسيم-الشغل-والمناقشة)
   - [الشخص الأول: صاحب الفكرة والمصادر وطبقة البرونز (Bronze)](#1-الشخص-الأول-صاحب-الفكرة--المصادر--البرونز)
   - [الشخص الثاني: مسؤول طبقة الفضة والتنظيف والجودة (Silver)](#2-الشخص-الثاني-مسؤول-الفضة--التنظيف-والجودة)
   - [الشخص الثالث: مسؤول طبقة الذهب والنمذجة ومؤشر الجاهزية (Gold)](#3-الشخص-الثالث-مسؤول-الذهب--النمذجة-ومؤشر-الجاهزية)
4. [الجزء الرابع: بنك الأسئلة المتوقعة للدكتور وإجاباتها النموذجية](#الجزء-الرابع-بنك-أسئلة-الدكتور-المتوقعة)
5. [الجزء الخامس: قائمة التحقق النهائية لطلبات الدكتور الـ 11 ومطابقتها](#الجزء-الخامس-مطابقة-طلبات-الدكتور-الـ-11)

---

# الجزء الأول: شرح المشروع الكامل

## 1. فكرة المشروع وسياق المملكة (Project Idea & Vision 2030)
المملكة العربية السعودية تضخ استثمارات استراتيجية ضخمة في حلول النقل الذكي والمركبات ذاتية القيادة (Autonomous Vehicles - AV) ضمن مستهدفات **رؤية السعودية 2030**، ومن أبرز هذه المشاريع:
- **مدينة نيوم (NEOM):** مصممة لتكون خالية من السيارات التقليدية معتمدة بنسبة 100% على النقل الذاتي المشترك.
- **شركة سير موتورز (Ceer Motors):** أول علامة تجارية سعودية لتصنيع السيارات الكهربائية وأنظمة القيادة الذاتية.
- **مصنع لوسيد (Lucid Motors) في مدينة الملك عبد الله الاقتصادية:** مركز إقليمي لإنتاج المركبات المتقدمة.

### ⚠️ التحدي الهندسي الأساسي (The Operational Design Domain Problem):
البيئة المناخية والجغرافية في المملكة تمثل واحدة من **أقسى بيئات التشغيل في العالم** لحساسات وأنظمة القيادة الذاتية (من المستوى 3 إلى المستوى 5 وفق تصنيف SAE) بسبب 3 تحديات رئيسية:
1. **العواصف الرملية وجزيئات الغبار ($PM_{10}$ و $PM_{2.5}$):**
   - العوالق الترابية تسبب تشتت وامتصاص لنبضات الليزر المنبعثة من حساسات الليدار (LiDAR Attenuation) بنسبة تتجاوز 60% إلى 80% في العواصف الشديدة مما يعمي الحساس تقنياً.
   - الكاميرات البصرية تفقد القدرة على كشف المسارات والعلامات المرورية وعوائق الطريق.
2. **درجات الحرارة القصوى (> 48°C صيفاً، وحرارة الأسفلت > 70°C):**
   - المعالجات والبطاقات الرسومية داخل المركبة المسؤولة عن خوارزميات الإدراك وتفادي الاصطدام تتعرض لاختناق حراري (Compute GPU Throttling).
   - تمدد الهواء داخل الإطارات بسبب حرارة الأسفلت العالية يؤدي إلى خطر الانفجار المفاجئ (Tire Blowout / Delamination).
3. **الوهج الشمسي الساطع (Solar Glare > 25 MJ/m²):**
   - يسبب إبهاراً مؤقتاً للكاميرات الأمامية خاصة وقت الظهيرة والغروب مما يعطل قراءة الإشارات والمسارات.

### 🎯 هدف المشروع:
بناء مستودع بيانات مؤسسي متعدد الطبقات (`av_ready_saudi_dw`) للإجابة الدقيقة على:
- **أين ومتى** يمكن للمركبات ذاتية القيادة العمل بأمان وموثوقية في المملكة؟
- **ما هي حدود التحمل الفيزيائية** للحساسات تحت الظروف المناخية القاسية؟
- **ما هي السياسات التشغيلية** التي يجب أن تفرضها غرف التحكم المروري وهيئات النقل (مثل تعليق القيادة الذاتية عند هبوب عاصفة ترابية أو تجاوز الحرارة 45°C)؟

---

## 2. الأسئلة التحليلية الخمسة للمشروع (Business Questions)
1. **تصنيف المخاطر البيئية على الحساسات (Sensor Hazard Rating):** كيف تؤثر العواصف الترابية والحرارة على كفاءة الليدار والكاميرات في المدن العشر الرئيسية؟
2. **ارتباط حوادث الطرق السريعة بالمناخ (Highway Corridor Accident Hotspots):** ما العلاقة بين الحوادث وتغيرات الطقس على الممرات الوطنية الكبرى (طريق 40، طريق 65، والمسارات الساحلية)؟
3. **مؤشر الجاهزية التشغيلي اليومي (Autonomous Readiness Index):** ما هو التقييم اليومي الموحد (من 0 إلى 100) الذي يحدد لغرف التحكم إمكانية تفعيل القيادة الذاتية؟
4. **تجزئة وتصنيف بيئات التشغيل (ODD Regime Clustering):** كيف تتوزع أيام وساعات السنة في كل مدينة إلى 3 نطاقات: مثالية (Optimal)، متوسطة المخاطر (Moderate)، وعالية الخطورة تمنع القيادة الذاتية (High Hazard)؟
5. **التنبؤ بانفصال النظام الآلي وتدخل السائق (Disengagement Prediction):** ما هي احتمالية عجز النظام الآلي عن القيادة عند اقتران سرعة الرياح بحرارة المعالجات وتدني مدى الرؤية؟

---

## 3. مصادر البيانات والنسبة المعتمدة (Sources & Real Data Ratio)

المشروع يعتمد على **3 مصادر أساسية** مجمعة ومحفوظة بصيغة CSV، بالإضافة إلى 3 ملفات متخصصة، بإجمالي **38,986 صفاً**:

| المصدر | اسم الملف | عدد الصفوف | نوع المصدر | المصدر المعتمد والتوثيق |
| :--- | :--- | :---: | :---: | :--- |
| **الطقس اليومي** | `Data/saudi_weather_daily_2019_2024.csv` | **21,920** | **بيانات حقيقية 100%** | Open-Meteo Historical API & ECMWF ERA5 (تغطي 10 مدن لـ 6 سنوات كاملة). |
| **الحوادث المرورية** | `Data/saudi_traffic_accidents_2019_2024.csv` | **5,066** | **بيانات رسمية معتمدة** | الهيئة العامة للإحصاء (GASTAT) عبر بوابة كابسارك المفتوحة (KAPSARC REST API) متطابقة مع ممرات الطرق الوطنية ومعايير UK DfT. |
| **التيليمتري وانفصال AV** | `Data/av_telemetry_failures_saudi.csv` | **12,000** | **محاكاة فيزيائية ومعايرة** | تقارير California DMV Disengagements و UC Berkeley TIMS وبيانات Microsoft PdM المفتوحة (تمت معايرتها بدقة عند 4000 رحلة لكل نمط عطل). |
| **الإجمالي العام** | **المستودع بالكامل** | **38,986** | — | **نسبة البيانات الحقيقية والرسمية:** $\frac{21,920 + 5,066}{38,986} = \mathbf{69.22\%}$ |

### 🔗 روابط التحميل المباشرة الموثقة عالمياً:
1. **طقس السعودية (Open-Meteo REST API):** [رابط التحميل المباشر للـ CSV](https://archive-api.open-meteo.com/v1/archive?latitude=24.7136&longitude=46.6753&start_date=2024-01-01&end_date=2024-12-31&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=Asia/Riyadh&format=csv)
2. **حوادث المرور السعودية (KAPSARC Official REST API):** [رابط التنزيل المباشر الرسمي من KAPSARC](https://datasource.kapsarc.org/api/explore/v2.1/catalog/datasets/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/exports/csv)
3. **تليماتري الحساسات من مايكروسوفت (Microsoft Raw CSV):** [رابط تحميل الملف الخام من GitHub مايكروسوفت](https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)
4. **تقارير اختبارات القيادة الذاتية (California DMV & Berkeley):** [بوابة كاليفورنيا الرسمية لاختبارات الـ AV](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/)

---

## 4. معمارية المستودع ومراحل التحويل (Medallion Architecture)

```
[ Data/ CSV Sources ]
   │  ├── saudi_weather_daily_2019_2024.csv    (21,920 rows)
   │  ├── saudi_traffic_accidents_2019_2024.csv (5,066 rows)
   │  └── av_telemetry_failures_saudi.csv       (12,000 rows)
   ▼
[ BRONZE LAYER ] ➔ (Untyped VARCHAR NULL, Verbatim Preservation, Provenance Columns)
   │  ├── bronze.sa_weather           (21,920 rows + source_file + ingested_at)
   │  ├── bronze.sa_traffic_accidents (5,066 rows + source_file + ingested_at)
   │  └── bronze.av_telemetry         (12,000 rows + source_file + ingested_at)
   ▼
[ SILVER LAYER ] ➔ (The 6 Core Verbs, Typed, Deduplicated, Surrogate Keys, Reject Log)
   │  ├── silver.sa_weather           (21,920 rows, weather_key INT IDENTITY)
   │  ├── silver.sa_traffic_accidents (5,066 rows, accident_key INT IDENTITY)
   │  ├── silver.av_telemetry         (12,000 rows, telemetry_key INT IDENTITY)
   │  └── silver.reject_log           (0 rows rejected - Clean Pipeline Gate)
   ▼
[ GOLD LAYER ] ➔ (Dimensional Star Schema, Pre-Aggregated CTEs, Readiness Metric)
   ├── Dimensions:
   │    ├── gold.dim_city            (10 Saudi cities & Climate Zones)
   │    ├── gold.dim_date            (2,192 distinct calendar dates)
   │    ├── gold.dim_weather_hazard  (WMO weather hazard categorization)
   │    └── gold.dim_av_failure_type (AV sensor failure taxonomy)
   └── Fact Table:
        └── gold.fact_daily_av_risk  (21,920 daily city observations with av_readiness_score)
```

---

# الجزء الثاني: خطوات التجهيز العملي

## 1. الترتيب الصحيح لتشغيل السكريبتات على SSMS
عند دخول المعمل، يتم فتح **SQL Server Management Studio (SSMS)** وتنفيذ الخطوات بالترتيب التالي:

### الخطوة 1: إنشاء قاعدة البيانات والمخططات (`sql/00_init.sql`)
- ينشئ قاعدة البيانات `av_ready_saudi_dw`.
- ينشئ المخططات الستة: `bronze`, `silver`, `gold`, `semantic`, `ml`, `audit`.
- ينشئ جدول تتبع التحميل `audit.load_log`.

### الخطوة 2: إنشاء جداول طبقة البرونز (`sql/01_bronze.sql`)
- ينشئ الجداول الثلاثة بنوع `VARCHAR(255) NULL` وعمودي التتبع `source_file` و `ingested_at`.
- ينشئ الـ Load Views (`bronze.v_sa_weather_load`, إلخ) لعزل أعمدة التتبع.
- ينشئ الإجراء المخزن `bronze.load_bronze`.

### الخطوة 3: استدعاء إجراء تحميل البرونز
افتح نافذة Query جديدة وتأكد من اختيار `av_ready_saudi_dw`:
```sql
USE av_ready_saudi_dw;
GO
EXEC bronze.load_bronze @base_path = N'D:\AV-Ready-Saudi\Data';
```
> **تنبيه:** تأكد أن مسار `@base_path` يشير لمجلد `Data` الفعلي على لابتوبك (مثلاً لو المشروع على سطح المكتب يكون `C:\Users\YourName\Desktop\AV-Ready-Saudi\Data`).

### الخطوة 4: إنشاء جداول طبقة الفضة (`sql/02_silver.sql`)
- ينشئ جداول الفضة ذات الأنواع الصريحة والـ Surrogate Keys.
- ينشئ جدول سجل الاستبعاد `silver.reject_log`.
- ينشئ الإجراء المخزن `silver.load_silver`.

### الخطوة 5: استدعاء إجراء تنظيف الفضة
```sql
USE av_ready_saudi_dw;
GO
EXEC silver.load_silver;
```

### الخطوة 6: إنشاء جداول وأبعاد طبقة الذهب (`sql/03_gold.sql`)
- ينشئ جداول الأبعاد الأربعة (`dim_city`, `dim_date`, `dim_weather_hazard`, `dim_av_failure_type`).
- ينشئ جدول الحقائق `gold.fact_daily_av_risk`.
- ينشئ الإجراء المخزن `gold.load_gold`.

### الخطوة 7: استدعاء إجراء تحميل الذهب
```sql
USE av_ready_saudi_dw;
GO
EXEC gold.load_gold;
```

---

## 2. النوافذ الواجب فتحها مسبقاً قبل دخول الدكتور
1. **برنامج SSMS:**
   - متصل بالسيرفر المحلي (`.\SQLEXPRESS` أو اسم لابتوبك).
   - تابات السكريبتات مفتوحة: `00_init.sql`, `01_bronze.sql`, `02_silver.sql`, `03_gold.sql`.
   - تاب استعلامات جاهز وفيه كود العرض السريع الموضح بالأسفل.
2. **برنامج VS Code أو المتصفح:**
   - مفتوح فيه مجلد المشروع `D:\AV-Ready-Saudi`.
   - تقارير الطبقات الثلاثة مفتوحة: `01_bronze_report.md`, `02_silver_report.md`, `03_gold_report.md`.
   - ملف المصادر مفتوح: `docs/DATA_SOURCES.md`.
3. **متصفح الإنترنت:**
   - صفحة المستودع على GitHub: `https://github.com/farahatsaafan/AV-Ready-Saudi`.
   - صفحة الـ Pull Request المفتوحة الخضراء (`Able to merge`).

---

## 3. استعلامات العرض السريع الجاهزة أمام الدكتور
انسخ هذا الكود في تاب منفصل في SSMS لتشغيله في ثانية واحدة إذا طلب الدكتور رؤية أي جدول:

```sql
USE av_ready_saudi_dw;
GO

-- 1. فحص التوازن الرياضي الشامل بين الطبقات (Reconciliation Gate)
SELECT 'Bronze Weather' AS Layer, COUNT(*) AS RowsCount FROM bronze.sa_weather
UNION ALL
SELECT 'Silver Weather', COUNT(*) FROM silver.sa_weather
UNION ALL
SELECT 'Bronze Accidents', COUNT(*) FROM bronze.sa_traffic_accidents
UNION ALL
SELECT 'Silver Accidents', COUNT(*) FROM silver.sa_traffic_accidents
UNION ALL
SELECT 'Bronze Telemetry (12k)', COUNT(*) FROM bronze.av_telemetry
UNION ALL
SELECT 'Silver Telemetry (12k)', COUNT(*) FROM silver.av_telemetry
UNION ALL
SELECT 'Silver Reject Log', COUNT(*) FROM silver.reject_log
UNION ALL
SELECT 'Gold Fact Table (21,920)', COUNT(*) FROM gold.fact_daily_av_risk;

-- 2. عرض نتائج مؤشر الجاهزية التشغيلي في طبقة الذهب (Top 10 Worst Days)
SELECT TOP 10
    c.city_name_en,
    d.calendar_date,
    f.av_readiness_score,
    f.max_temp_c,
    f.max_wind_gusts_kmh,
    f.is_dust_storm,
    f.daily_accident_count,
    f.daily_disengagements_count
FROM gold.fact_daily_av_risk f
JOIN gold.dim_city c ON f.city_key = c.city_key
JOIN gold.dim_date d ON f.date_key = d.date_key
ORDER BY f.av_readiness_score ASC;

-- 3. سجل تتبع عمليات التحميل التلقائية (Audit Log)
SELECT TOP 10 * FROM audit.load_log ORDER BY start_time DESC;
```

---

# الجزء الثالث: تقسيم الشغل والمناقشة

## 1. الشخص الأول: صاحب الفكرة + المصادر + البرونز
### 💻 ما يتم فتحه على لابتوبه:
- ملف `docs/PROJECT_SPEC.md` و `docs/DATA_SOURCES.md`.
- ملف سكريبت البرونز `sql/01_bronze.sql`.
- تقرير البرونز `docs/reports/01_bronze_report.md`.
- شاشة SSMS تعرض استعلام: `SELECT TOP 10 * FROM bronze.sa_weather;` و `SELECT TOP 10 * FROM audit.load_log;`.

### 🗣️ السيناريو وطريقة الإلقاء أمام الدكتور:
> "أهلاً بحضرتك يا دكتور. فكرة مشروعنا هي **AV-Ready-Saudi**: مستودع بيانات مؤسسي لتقييم جاهزية الطرق في المملكة العربية السعودية لتشغيل المركبات ذاتية القيادة (Autonomous Vehicles).
> 
> المملكة مستثمرة بقوة في نيوم وسير موتورز ومصنع لوسيد، ولكن بيئة المملكة صعبة جداً على الحساسات: عواصف رملية بتعمي الليدار بنسبة امتصاص تتجاوز 70%، وحرارة صيف تتخطى 48°C بتعمل اختناق حراري للمعالجات وتمدد للإطارات، ووهج شمسي شديد بيعطل الكاميرات.
> 
> جمعنا بياناتنا من 3 مصادر موثوقة: الطقس لـ 10 مدن على مدار 6 سنين (21,920 صف) من Open-Meteo و ECMWF، والحوادث المرورية (5,066 صف) مستندة لإحصاءات GASTAT الرسمية المنشورة عبر بوابة KAPSARC الحكومية، وتيليمتري المركبات الذكية (12,000 صف) بمعايرة فيزيائية لـ 50 مركبة ذكية بالاعتماد على تقارير California DMV Disengagements ومعايير مايكروسوفت. إجمالي بياناتنا 38,986 صفاً بنسبة موثوقية واقعية **69.2%**.
> 
> أنا مسؤول عن **الطبقة البرونزية (Bronze Layer)**: طبقنا فيها مبدأ **Untyped Landing Layer**؛ كل الأعمدة بتنزل `VARCHAR(255) NULL` بدون أي تعديل أو تنظيف صامت (Verbatim Preservation) عشان نمنع أي Ingestion Failure. وأضفنا عمودين أساسيين للـ Data Provenance: اسم الملف المصدر `source_file` ولحظة الإدخال `ingested_at`. وعملنا Load Views عشان تفصل أعمدة الـ Provenance عن الـ Bulk Insert، والإجراء المخزن `bronze.load_bronze` بيسجل كل خطوة في جدول التدقيق `audit.load_log`."

---

## 2. الشخص الثاني: مسؤول الفضة + التنظيف والجودة
### 💻 ما يتم فتحه على لابتوبه:
- ملف سكريبت الفضة `sql/02_silver.sql`.
- تقرير الفضة `docs/reports/02_silver_report.md`.
- شاشة SSMS تعرض:
  - استعلام فحص التوازن الرياضي (Reconciliation Query).
  - استعلام جدول سجل المرفوضات: `SELECT * FROM silver.reject_log;`.

### 🗣️ السيناريو وطريقة الإلقاء أمام الدكتور:
> "أنا مسؤول يا دكتور عن **الطبقة الفضية (Silver Layer)**، ودي الطبقة المسؤولة عن تحويل البيانات الخام المجهولة إلى **Trusted Enterprise Data** نقدر نبني عليها قرارات مؤسسية.
> 
> المنهجية اللي طبقناها هي منهجية **الأفعال الستة (The 6 Core Verbs)**:
> 1. **Trim:** إزالة المسافات البيضاء من البداية والنهاية باستخدام دالة `NULLIF(LTRIM(RTRIM(col)), '')` بحيث لو القيمة مسافات بس تتحول لـ NULL صريح.
> 2. **Standardize:** توحيد النصوص وحالة الأحرف (مثل تحويل كود المدينة لـ UPPER كـ RUH, JED).
> 3. **Convert:** التحويل الآمن للأنواع باستخدام `TRY_CONVERT` للتواريخ والأرقام العشرية و `CASE WHEN` للمتغيرات المنطقية BIT، عشان لو في قيمة مشوهة ما تكسرش الكود وإنما ترجع NULL.
> 4. **Deduplicate:** حذف التكرارات اعتماداً على مفتاح العمل الطبيعي (Natural Business Key) بواسطة الدالة التحليلية `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) = 1`.
> 5. **Validate & Quarantine:** عزل الصفوف التي تخالف القواعد الفيزيائية والمنطقية (زي حرارة خارج نطاق -15 إلى 65 مئوية أو سرعة غير منطقية) ونقلها فوراً لجدول العزل `silver.reject_log` مع ذكر سبب الرفض بالتفصيل.
> 6. **Transaction Safety:** كل عمليات التحميل محاطة بـ `BEGIN TRAN ... COMMIT` مع تفعيل `SET XACT_ABORT ON` لضمان مبدأ الـ All-or-Nothing الذري.
> 
> كمان أضفنا مفاتيح بديلة **Surrogate Keys** لكل جدول (`weather_key`, `accident_key`, `telemetry_key`) باستخدام `INT IDENTITY`، وعمود تدقيق زمني `DW_create_date`.
> 
> وحققنا معادلة التوازن الرياضي (Reconciliation Gate) بنسبة **100%**:
> $$\text{Bronze} (38,986) = \text{Silver} (38,986) + \text{Reject} (0) + \text{Duplicates} (0)$$
> وكل البيانات سليمة وموثقة بنسبة موثوقية 69.2%."

---

## 3. الشخص الثالث: مسؤول الذهب + النمذجة ومؤشر الجاهزية
### 💻 ما يتم فتحه على لابتوبه:
- ملف سكريبت الذهب `sql/03_gold.sql`.
- تقرير الذهب `docs/reports/03_gold_report.md`.
- شاشة SSMS تعرض:
  - استعلام الـ Star Schema لجدول الحقائق وربطه بالأبعاد مع مؤشر الجاهزية:
    `SELECT TOP 10 * FROM gold.fact_daily_av_risk ORDER BY av_readiness_score ASC;`.

### 🗣️ السيناريو وطريقة الإلقاء أمام الدكتور:
> "أنا مسؤول يا دكتور عن **الطبقة الذهبية (Gold Layer)**، ودي الطبقة التحليلية الأهم اللي بتمثل مخرجات المستودع لمتخذي القرار وغرف التحكم المروري.
> 
> صممنا الطبقة الذهبية وفق نموذج **Star Schema** احترافي بيتكون من:
> - **4 جداول أبعاد (Dimensions):**
>   1. `dim_city`: يضم المدن الـ 10 وإحداثياتها ونطاقها المناخي (مثل Desert Continental أو Coastal Humid).
>   2. `dim_date`: يضم 2,192 يوماً تقويمياً فريداً مع تفاصيل السنة والشهر واسمه والربع السنوي.
>   3. `dim_weather_hazard`: تصنيف مخاطر الطقس وفق أكواد المنظمة العالمية للأرصاد (WMO).
>   4. `dim_av_failure_type`: تصنيف الأعطال الفرعية للحساسات والأنظمة الميكانيكية.
> - **جدول حقائق مركزي (Fact Table):** `gold.fact_daily_av_risk`
>   - **درجة الحبيبية (Grain):** صف واحد لكل مدينة في كل يوم تقويمي (`One row per city per date`) بإجمالي **21,920 صفاً**.
>   - قمنا بربط الطقس كأساس (Base)، واستخدمنا **LEFT JOIN مع ISNULL** للحوادث والتيليمتري بعد عمل تجميع مسبق (Pre-aggregation) عبر CTEs؛ وده لأن مش كل يوم فيه حوادث أو تجارب مركبات ذاتية، واستخدام INNER JOIN كان هيحذف الأيام الآمنة ويشوه المستودع!
> 
> وقمنا ببناء وحساب **مؤشر الجاهزية التشغيلي اليومي للمركبات الذاتية (Autonomous Readiness Index)** من 0 إلى 100 بالمعادلة:
> $$\text{Score} = 100 - (35 \times \text{Dust}) - (20 \times \text{Heat}) - (15 \times \text{Wind}) - (5 \times \text{Accidents}) - (8 \times \text{Disengagements})$$
> 
> - **تفسير الأوزان:** العاصفة الترابية بتخصم 35 نقطة لأنها أخطر مهدد بيعطل الليدار والكاميرا معاً، والحرارة القصوى بتخصم 20 نقطة لاختناق المعالجات والبطارية، والرياح الشديدة 15 نقطة.
> - **المؤشر بيصنف الأيام لـ 3 نطاقات تشغيل:**
>   - **90 - 100 (Optimal):** تشغيل كامل للقيادة الذاتية.
>   - **60 - 89 (Moderate Risk):** قيادة ذاتية بحذر مع تفعيل حساسات مساندة.
>   - **أقل من 60 (High Hazard):** تعليق فوري للقيادة الذاتية وتسليم التحكم للسائق البشري.
> 
> وبكده حققنا التكامل التام بين الطبقات: فلو البرونز مش سليم، الفضة هتبوظ، وبالتالي الذهب هيكون مضلل، ومستودعنا محكم بنسبة 100%."

---

# الجزء الرابع: بنك أسئلة الدكتور المتوقعة

### س1: ليه اخترتوا المملكة العربية السعودية بالذات؟
**الإجابة:** لأن المملكة تقود المنطقة في مشاريع النقل الذكي ضمن رؤية 2030 (نيوم، سير، لوسيد)، وفي نفس الوقت تمتلك واحدة من أصعب بيئات التشغيل في العالم (عواصف رملية، حرارة تتجاوز 48°C، وهج شمسي)، وده بيخلي دراسة جاهزية الطرق موضوعاً حيوياً ومطلوباً هندسياً وميدانياً.

### س2: ما هي مصادر البيانات وهل هي حقيقية فعلاً؟
**الإجابة:** نعم يا دكتور، **69.2% من بيانات المستودع بيانات حقيقية ورسمية**:
- الطقس حقيقي 100% (21,920 صفاً) من Open-Meteo و ECMWF ERA5.
- الحوادث (5,066 صفاً) مستندة لإحصاءات الهيئة العامة للإحصاء (GASTAT) الرسمية عبر بوابة كابسارك (KAPSARC REST API).
- التيليمتري (12,000 صف) تمت معايرته بدقة وفق تقارير California DMV Disengagements وبيانات مايكروسوفت المفتوحة، مع الحفاظ على الأنماط الفيزيائية للعواصف والحرارة وضغط الإطارات.

### س3: ليه مخزنين كل أعمدة البرونز كـ VARCHAR(255)؟
**الإجابة:** عشان نطبق مبدأ **Permissive Schema / Raw Ingestion**. في هندسة البيانات المؤسسية، خطوة التحميل الأولي (Ingestion) لازم تقبل أي داتا جاية من المصدر بدون ما تفشل؛ التحويل الصريح والتنظيف مكانه الصحيح في الطبقة الفضية (Silver).

### س4: ما هو الـ Provenance وليه ضفتوه؟
**الإجابة:** هو إمكانية تتبع أصل وسجل البيانات (Data Lineage). ضفنا عمودين: `source_file` (اسم الملف المصدر) و `ingested_at` (وقت التحميل الدقيق بالسيرفر) عشان لو حصل أي تدقيق أو مراجعة في المستقبل نعرف السجل ده جه منين وبالتحديد إمتى.

### س5: ليه جدول `silver.reject_log` فاضي في التحميل الحالي؟ هل كود الـ Validation شغال؟
**الإجابة:** كود الـ Validation شغال ومكتوب بالكامل داخل `silver.load_silver`؛ والجدول فاضي لأن ملفات الـ CSV تم تجهيزها واختبار جودتها مسبقاً فلا تحتوي على أخطاء فيزيائية مستحيلة. ولو دخلنا صفاً غير منطقي (مثلاً حرارة 90°C أو سرعة 400 كم/س) الإجراء هيستبعده فوراً ويسجله في `silver.reject_log`.

### س6: ما الفرق بين `CONVERT` و `TRY_CONVERT`؟
**الإجابة:** أمر `CONVERT` لو قابل نص غير قابل للتحويل (مثلاً تاريخ مكتوب حروف) بيرمي خطأ (Error) وبيوقف تنفيذ الإجراء بالكامل. أما `TRY_CONVERT` فبيرجع `NULL` بهدوء لو فشل التحويل، وده بيحمي Pipeline التحميل من التوقف المفاجئ.

### س7: ليه استخدمتوا `ROW_NUMBER()` مش `DISTINCT` لإزالة التكرارات في الفضة؟
**الإجابة:** لأن `DISTINCT` بتبص على كل أعمدة الصف بالكامل؛ لو في صف متكرر فيه اختلاف في عمود واحد مش هتشيله. أما `ROW_NUMBER() OVER (PARTITION BY [Natural_Keys])` فبتمكننا من تحديد مفاتيح العمل بدقة (زي `date + city_id`) وحذف أي تكرار مع الاحتفاظ بالنسخة الأولى (`WHERE rn = 1`).

### س8: يعني إيه دقة السجل (Grain) في جدول الحقائق بالذهب؟
**الإجابة:** الـ Grain هو أدنى مستوى تفصيلي يمثله السطر الواحد في جدول الحقائق. في مشروعنا الـ Grain هو: **"سجل واحد لكل مدينة في كل يوم تقويمي"** (`One row per city per date`)، وإجمالي صفوفه 21,920 صفا (10 مدن × 2,192 يوماً).

### س9: ليه عملتوا `LEFT JOIN` مع الحوادث والتيليمتري مش `INNER JOIN` في جدول الحقائق؟
**الإجابة:** لأن مش كل مدينة بيحصل فيها حادثة أو تجربة سيارة ذاتية في كل يوم. لو استخدمنا `INNER JOIN` هنحذف كل الأيام الآمنة اللي ما كانش فيها حوادث، وده هيشوه التحليل الإحصائي! الـ `LEFT JOIN` مع دالة `ISNULL(..., 0)` بيضمن بقاء كافة الأيام المناخية مع تسجيل 0 حوادث للأيام الهادئة.

### س10: ليه استخدمتوا معادلة إحصائية (Rule-Based) لحساب الجاهزية مش موديل Machine Learning؟
**الإجابة:** لأن أنظمة السلامة الحرجة في قطاع الطيران والمركبات الذكية تتطلب **قابلية تفسير كاملة (Explainability)** للمسؤولين وغرف التحكم لمعرفة سبب تعليق القيادة الذاتية بدقة. الموديلات المعقدة (Black Box) غير مقبولة تشريعياً كمعيار سلامة أولي، ولكن تم تجهيز فيوز خاصة (`gold.features_trip_telemetry`) لتدريب نماذج Decision Trees و Clustering في مرحلة التنبؤ اللاحقة.

---

# الجزء الخامس: مطابقة طلبات الدكتور الـ 11

| # | طلب الدكتور | الملف / الموقع داخل المشروع | الحالة والتأكيد |
| :-: | :--- | :--- | :-: |
| **1** | **Sources links and datasets** | مجلد `Data/` (يحتوي على الملفات الستة كاملة) + ملف `docs/DATA_SOURCES.md` + `docs/data_source_register_clean.csv` | **مكتمل وموثق 100% بالروابط المباشرة لـ KAPSARC و Open-Meteo و Microsoft** |
| **2** | **Idea question** | ملف `docs/IDEA_QUESTIONS.md` + `docs/PROJECT_SPEC.md` + `README.md` | **مكتمل ويجيب على الأسئلة الخمسة لبيئات ODD** |
| **3** | **Bronze SQL script** | `sql/01_bronze.sql` و `sql/bronze/proc_load_bronze.sql` | **مكتمل مع Load Views وإجراء التحميل التلقائي** |
| **4** | **Bronze database** | قاعدة `av_ready_saudi_dw` ومخطط `bronze.*` (3 جداول) | **منفذ ومحمل بالكامل (38,986 صفاً)** |
| **5** | **Bronze report** | `docs/reports/01_bronze_report.md` | **مكتمل ومحدث بأعداد الصفوف ومطابقة البيانات** |
| **6** | **Silver SQL script** | `sql/02_silver.sql` و `sql/silver/proc_load_silver.sql` | **مكتمل بالأفعال الستة وعزل المرفوضات** |
| **7** | **Silver database** | قاعدة `av_ready_saudi_dw` ومخطط `silver.*` (3 جداول + `reject_log`) | **منفذ ومحمل بنسبة توازن 100%** |
| **8** | **Silver report** | `docs/reports/02_silver_report.md` | **مكتمل ومعادلة التوازن الرياضي موثقة** |
| **9** | **Gold Script** | `sql/03_gold.sql` و `sql/gold/proc_load_gold.sql` | **مكتمل بنموذج Star Schema ومؤشر الجاهزية** |
| **10** | **Gold database** | قاعدة `av_ready_saudi_dw` ومخطط `gold.*` (4 أبعاد + جدول الحقائق) | **منفذ ومحمل بدقة Grain يومية كاملة** |
| **11** | **Gold report** | `docs/reports/03_gold_report.md` | **مكتمل ويحتوي على تحليل الجاهزية والنطاقات** |

---

### 💡 ملخص التوصيات لصباح المناقشة:
1. تأكد من فتح السيرفر وتشغيل الخطوات من 1 إلى 7 على لابتوب كل عضو في الفريق.
2. افتح النوافذ المحددة في الدليل مسبقاً قبل وصول الدكتور.
3. كل شخص يركز على دوره الأساسي مع فهم الرابط بين الطبقات ("ما بُني على باطل فهو باطل").
4. بالتوفيق والدرجة النهائية إن شاء الله! 🚀
