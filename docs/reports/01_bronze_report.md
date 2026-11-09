# تقرير الطبقة البرونزية (Bronze Layer Report)

**المشروع:** AV-Ready-Saudi  
**المقرر:** مستودعات البيانات والتنقيب (Data Mining & Data Warehousing)  
**الطبقة:** Bronze Layer (Raw Landing & Provenance)  
**قاعدة البيانات:** `av_ready_saudi_dw`  
**الـ Schema المستهدف:** `bronze.*`  

---

## 1. الهدف المعماري للطبقة البرونزية (Architectural Objective)
وفقاً لمبادئ معمارية الميداليون وقواعد المقرر (Unit 2 Lab 3 & Course Skeleton Fall 2026):
1. **الحفظ الحرفي (Verbatim Preservation):** استقبال ملفات البيانات الخام كما وردت من مصادرها الأصلية تماماً بدون أي تعديل أو تنظيف صامت (No silent cleaning).
2. **المخطط المرن المتسامح (Permissive Schema):** تخزين كافة الأعمدة بصيغة نصوص `VARCHAR / NVARCHAR NULL` لتجنب فشل عمليات التحميل المجمع (Zero Ingestion Abort).
3. **تتبع الأصل والنسب (Data Provenance):** إضافة عمودين تقنيين إلزاميين لكل صف:
   * `source_file VARCHAR(500)`: اسم ملف المصدر.
   * `ingested_at DATETIME2`: اللحظة الزمنية الدقيقة لعملية الإدخال.

---

## 2. مصادر البيانات المحملة في البرونز (Ingested Datasets)

| اسم الجدول | اسم ملف المصدر | عدد الصفوف | عدد الأعمدة | المصدر والجهة المرجعية |
| :--- | :--- | :---: | :---: | :--- |
| `bronze.sa_weather` | `saudi_weather_daily_2019_2024.csv` | **21,920** | 16 + 2 Provenance | أرشيف Open-Meteo التاريخي (ERA5 / محطات الأرصاد السعودية NCM) |
| `bronze.sa_traffic_accidents` | `saudi_traffic_accidents_2019_2024.csv` | **5,066** | 11 + 2 Provenance | الهيئة العامة للإحصاء (GASTAT) ووزارة النقل السعودية |
| `bronze.av_telemetry` | `av_telemetry_failures_saudi.csv` | **15,000** | 14 + 2 Provenance | تقارير California DMV Disengagements ومعادلات Fraunhofer الفيزيائية |
| **الإجمالي** | **3 مصادر أساسية** | **41,986** | — | — |

---

## 3. آلية التحميل المجمع (Automated Batch Ingestion)
* تم بناء سكريبت `sql/01_bronze.sql` الذي ينشئ:
  1. جداول الهبوط الثلاثة في الـ schema `bronze`.
  2. فيوز التحميل المساعد (`bronze.v_*_load`) التي تسمح لـ `BULK INSERT` بتحميل أعمدة الـ CSV مع احتفاظ عمودي الـ Provenance بقيمهما التلقائية.
  3. الإجراء المخزن المجمع `bronze.load_bronze` المزود بـ `TRUNCATE TABLE`، ترميز `CODEPAGE = '65001'` (UTF-8)، وتسجيل عمليات الدفعات في جدول التدقيق `audit.load_log`.

---

## 4. تقرير عيوب البيانات المرصودة في البرونز (Observed Defects Profile)
تم الإبقاء على كافة العيوب والشوائب عمداً داخل طبقة البرونز ليتم معالجتها بشفافية ومطابقتها في طبقة الفضة:
* **مسافات بيضاء زائدة (Trailing & Leading Whitespaces):** رُصدت في أسماء الطرق وأسماء المدن.
* **أنواع البيانات النصية:** كافة الأرقام والتواريخ مخزنة كنصوص (`VARCHAR`) ولم يتم تحويلها لتفادي أخطاء التحويل أثناء الـ Ingest.
* **القيم المفقودة والفارغة (Blanks):** تم الاحتفاظ بالنصوص الفارغة كما هي (`''`) ليتم تحويلها لاحقاً إلى `NULL` حقيقي أو معالجتها في الفضة.

---

## 5. حالة الجاهزية للطبقة الفضية
* كافة الجداول الثلاثة محملة بنسبة 100% (41,986 صفاً).
* تم التحقق من سلامة الأعداد عبر جدول التدقيق `audit.load_log`.
* البيانات جاهزة تماماً للانتقال إلى إجراء التنظيف والمطابقة `silver.load_silver`.
