# 📘 الدليل الشامل والمفصل لمشروع AV-Ready-Saudi — النسخة النهائية للمناقشة
### الخلاصة المركزة + الفكرة العامة + الشرح التفصيلي لعمل كل شخص وسيناريو الإلقاء
**تاريخ التحديث:** 16 نوفمبر 2026  
**المشروع:** مستودع بيانات جاهزية الطرق السعودية لتشغيل المركبات ذاتية القيادة (`AV-Ready-Saudi`)  
**المعمارية:** Medallion Data Architecture (Bronze ➔ Silver ➔ Gold)  
**نسبة البيانات الموثقة:** **69.22%** بيانات واقعية ورسمية (26,986 صفاً رسمياً من أصل 38,986 صفاً)

---

# 📑 فهرس محتويات الدليل
1. [الخريطة الذهنية للمناقشة (كيف نُبهر الدكتور في أول دقيقتين؟)](#-الخريطة-الذهنية-للمناقشة)
2. [الشخص الأول: صاحب فكرة المشروع + المصادر + الطبقة البرونزية (Bronze Layer)](#1-الشخص-الأول-صاحب-فكرة-المشروع--المصادر--الطبقة-البرونزية)
   - الخلاصة المركزة (Cheat Sheet)
   - الفلسفة الهندسية للجزئية (The Concept)
   - الشرح التفصيلي خطوة بخطوة
   - السيناريو الحواري المباشر أمام الدكتور (Script)
   - بنك الأسئلة المتوقعة وإجاباتها القاطعة
3. [الشخص الثاني: مسؤول الطبقة الفضية (Silver Layer) وجودة البيانات (Data Quality)](#2-الشخص-الثاني-مسؤول-الطبقة-الفضية-وجودة-البيانات)
   - الخلاصة المركزة (Cheat Sheet)
   - الفلسفة الهندسية للجزئية (The Concept)
   - الشرح التفصيلي للأفعال الستة (The 6 Core Verbs)
   - السيناريو الحواري المباشر أمام الدكتور (Script)
   - بنك الأسئلة المتوقعة وإجاباتها القاطعة
4. [الشخص الثالث: مسؤول الطبقة الذهبية (Gold Layer) ومؤشر الجاهزية (Readiness Score)](#3-الشخص-الثالث-مسؤول-الطبقة-الذهبية-والنمذجة-البعدية)
   - الخلاصة المركزة (Cheat Sheet)
   - الفلسفة الهندسية للجزئية (The Concept)
   - الشرح التفصيلي للـ Star Schema والـ Fact Table
   - السيناريو الحواري المباشر أمام الدكتور (Script)
   - بنك الأسئلة المتوقعة وإجاباتها القاطعة
5. [كود العرض السريع على SSMS (شاشات الإثبات الفوري)](#-كود-العرض-السريع-على-ssms)
6. [جدول مطابقة طلبات الدكتور الـ 11 بالكامل](#-جدول-مطابقة-طلبات-الدكتور-الـ-11)

---

# 🧠 الخريطة الذهنية للمناقشة

> [!IMPORTANT]
> **القاعدة الذهبية التي يركز عليها الدكتور:**  
> **"ما بُني على باطل فهو باطل"**  
> تعني أن كل طبقة تسلم الطبقة التالية:
> 1. **البرونز (Bronze):** استقبل البيانات الخام بدقة وحفظ أصلها (Data Lineage) بدون أي فقدان.
> 2. **الفضة (Silver):** نظفت وطبقت القواعد الفيزيائية وحققت التوازن بنسبة 100% (Reconciliation Gate).
> 3. **الذهب (Gold):** بنت نموذج الأبعاد والحقائق وحسبت مؤشر الجاهزية لدعم القرار.
> **لذلك: كل شخص لازم يعرف جزئيته جيداً، ويعرف كيف تسلم جزئيته لزميله التالي!**

---

# 1. الشخص الأول: صاحب فكرة المشروع + المصادر + الطبقة البرونزية

## 📌 أولاً: الخلاصة المركزة للشخص الأول (Cheat Sheet)
- **مهمتك:** افتتاح المناقشة، إبهار الدكتور بسياق المشروع الوطني (رؤية 2030)، توضيح الأرقام والمصادر الموثوقة (69.2% بيانات واقعية ورسمية)، وشرح معمارية استقبال البيانات الخام في البرونز.
- **الكلمات المفتاحية التي يجب أن ترددها:**
  `ODD (Operational Design Domain)`, `SAE Level 3-5`, `Neom & Ceer`, `LiDAR Attenuation`, `Permissive Schema`, `Verbatim Preservation`, `Data Provenance (source_file, ingested_at)`, `Load Views`, `audit.load_log`.
- **أهم جملة تفتتح بها:**  
  *"يا دكتور، مشروعنا بيبني Data Warehouse عشان يجاوب على سؤال استراتيجي لهيئات النقل وغرف التحكم: إمتى وفين سيارات القيادة الذاتية تقدر تمشي بأمان في السعودية، وإمتى لازم النظام يفصل ويسلم السائق فوراً؟"*

---

## 🏛️ ثانياً: الفكرة الهندسية للجزئية (The Concept)
### 1. لماذا السعودية؟
المملكة ليست مجرد سوق استهلاكي، بل تستثمر مليارات الدولارات لتكون مركزاً عالمياً للمركبات الذكية (مدينة **نيوم NEOM** المخططة بالكامل للنقل الذاتي، شركة **سير موتورز Ceer** الوطنية، ومصنع **لوسيد Lucid**). لكن بيئة المملكة المناخية تمثل **واحدة من أقسى بيئات التشغيل في العالم (Harsh ODD)** بسبب:
- **العواصف الرملية الغبارية:** ذرات الـ $PM_{10}$ و $PM_{2.5}$ بتشتت نبضات الليدار (LiDAR Attenuation > 70%) وتعمي الكاميرات.
- **الحرارة القصوى (> 48°C وأسفلت > 70°C):** اختناق حراري لمعالجات الذكاء الاصطناعي (GPU Throttling) وانفجار إطارات.
- **الوهج الشمسي الساطع (> 25 MJ/m²):** إبهار الكاميرات وقت الظهيرة.

### 2. مصادر البيانات ومعايرة المصداقية (38,986 صفاً):
- **الطقس (21,920 صفاً):** حقيقي 100% من **Open-Meteo API & ECMWF ERA5** يغطي 10 مدن على مدار 6 سنين كاملة.
- **الحوادث (5,066 صفاً):** بيانات رسمية من **الهيئة العامة للإحصاء (GASTAT)** منشورة عبر بوابة **كابسارك الحكومية (KAPSARC REST API)** ومطابقة لممرات الطرق الوطنية ومعايير UK DfT.
- **التيليمتري (12,000 صف):** معايرة فيزيائية دقيقة (4,000 لكل نمط عطل) مستندة لتقارير **California DMV Disengagements** ومايكروسوفت.
- **نسبة الواقعية:** $\frac{21,920 + 5,066}{38,986} = \mathbf{69.22\%}$ (بيانات رسمية واقعية بدون فبركة خلايا).

### 3. فلسفة البرونز (Untyped Raw Landing):
- تخزين كل الأعمدة كـ `VARCHAR(255) NULL` بدون أي تعديل للأصل (Verbatim Preservation).
- إضافة عمودي تتبع الأثر: `source_file` و `ingested_at`.
- عزل الأعمدة الإضافية عبر `Load Views` لتسريع التحميل بـ `BULK INSERT`.
- تسجيل كل عملية تحميل في جدول التدقيق `audit.load_log`.

---

## 🔍 ثالثاً: الشرح التفصيلي لعمل الشخص الأول

### 1. إنشاء الجداول وتصميم المخطط:
في سكريبت [sql/01_bronze.sql](file:///d:/AV-Ready-Saudi/sql/01_bronze.sql)، تم إنشاء 3 جداول هبوط:
```sql
CREATE TABLE bronze.sa_weather (
    date_raw VARCHAR(255) NULL,
    city_id_raw VARCHAR(255) NULL,
    temp_max_raw VARCHAR(255) NULL,
    temp_min_raw VARCHAR(255) NULL,
    wind_gusts_raw VARCHAR(255) NULL,
    weather_code_raw VARCHAR(255) NULL,
    -- أعمدة التتبع (Provenance Metadata)
    source_file NVARCHAR(255) NULL,
    ingested_at DATETIME2 DEFAULT SYSDATETIME()
);
```

### 2. حل معضلة الـ BULK INSERT عبر Load Views:
لو حاولت تعمل `BULK INSERT` مباشرة في جدول فيه أعمدة `source_file` و `ingested_at`، السيرفر هيرمي Error لأن ملف الـ CSV ما فيهوش العمودين دول!
**الحل الهندسي:** عملنا `VIEW` يقرأ أعمدة الـ CSV فقط:
```sql
CREATE OR ALTER VIEW bronze.v_sa_weather_load AS
SELECT date_raw, city_id_raw, temp_max_raw, temp_min_raw, wind_gusts_raw, weather_code_raw
FROM bronze.sa_weather;
```
ثم التحميل يتم عبر الـ View، وبعد انتهاء الـ Bulk يتم تحديث `source_file` باسم الملف الفعلي.

### 3. الإجراء المخزن `bronze.load_bronze`:
- يأخذ بارامتر واحد: `@base_path` (مسار فولدر Data).
- ينفذ `TRUNCATE TABLE` لكل جدول هبوط لضمان عدم تكرار التحميل (Idempotent).
- ينفذ `BULK INSERT` لكل جدول.
- يسجل بداية ونهاية العملية وعدد الصفوف المحملة وحالتها (`SUCCESS` أو `FAILED`) في `audit.load_log`.

---

## 🗣️ رابعاً: السيناريو وطريقة الإلقاء أمام الدكتور (Script)

> **ابدأ بالثقة دي:**  
> "أهلاً يا دكتور. فكرة مشروعنا هي **AV-Ready-Saudi**: مستودع بيانات مؤسسي لتقييم جاهزية الطرق السعودية لتشغيل المركبات ذاتية القيادة.
> 
> المملكة متجهة بقوة نحو مشاريع القيادة الذاتية زي نيوم وسير ولوسيد، ولكن بيئة المملكة بتفرض تحديات فيزيائية قاسية جداً على الحساسات: عواصف رملية بتخفض كفاءة الليدار بأكتر من 70%، وحرارة تتجاوز 48°C بتعمل اختناق حراري للمعالجات، ووهج شمسي بيعطل الكاميرات.
> 
> جمعنا 3 مصادر أساسية: الطقس اليومي لـ 10 مدن لـ 6 سنين كاملة (21,920 صف) من Open-Meteo و ECMWF، والحوادث المرورية (5,066 صف) من إحصاءات الهيئة العامة للإحصاء الرسمية عبر بوابة كابسارك REST API، وبيانات التيليمتري (12,000 صف) بمعايرة فيزيائية لـ 50 مركبة ذكية بالاعتماد على اختبارات California DMV ومايكروسوفت. الإجمالي عندنا **38,986 صفاً**، بنسبة بيانات حقيقية ورسمية **69.2%**.
> 
> أنا مسؤول عن **الطبقة البرونزية (Bronze)**: صممناها كـ **Untyped Landing Layer**؛ كل الأعمدة بتنزل `VARCHAR(255) NULL` بهدف الحفاظ الحرفي على الداتا (Verbatim Preservation) وتفادي أي فشل أثناء الـ Ingestion. وأضفنا عمودين للـ Provenance: اسم الملف المصدر `source_file` ووقت التحميل `ingested_at`. وعشان نقدر نعمل Bulk Insert بدون تعارض، صممنا `Load Views`، وربطنا العملية بإجراء مخزن `bronze.load_bronze` بيسجل كل خطوة في جدول التدقيق `audit.load_log`."

---

## ❓ خامساً: بنك أسئلة الدكتور للشخص الأول
- **س1: ليه كل الأعمدة في البرونز VARCHAR مش بأنواعها الحقيقية؟**  
  *الإجابة:* عشان مبدأ الـ **Permissive Schema**. البرونز وظيفته استقبال البيانات كما هي دون أي رفض أو تنظيف صامت. التحويل للأنواع المناسبة (Casting) مكانه الصحيح في الطبقة الفضية (Silver).
- **س2: هل بيانات الحوادث حقيقية ولا من عندكم؟**  
  *الإجابة:* حقيقية ورسمية يا دكتور؛ معتمدة على إحصاءات الهيئة العامة للإحصاء (GASTAT) المنشورة عبر بوابة كابسارك الحكومية (KAPSARC REST API)، ومربوطة بممرات الطرق السريعة ومعايير UK DfT.
- **س3: ليه التيليمتري 12,000 صف مش رقم تاني؟**  
  *الإجابة:* عايرنا حجم التيليمتري ليكون 4,000 رحلة لكل نمط عطل رئيسي (غبار، حرارة، ضغط إطارات) عشان نحقق توازن علمي ونسبة واقعية معتمدة 69.2% بدون تضخيم وهمي للبيانات.
- **س4: إيه فايدة الـ Load Views في البرونز؟**  
  *الإجابة:* أمر `BULK INSERT` في SQL Server بيتوقع أن عدد أعمدة الجدول يطابق عدد أعمدة ملف الـ CSV تماماً. وبما أننا ضفنا عمودي `source_file` و `ingested_at`، فالـ Load View بيعزل الأعمدة دي ويسمح بالتحميل السريع بدون أخطاء.

---

# 2. الشخص الثاني: مسؤول الطبقة الفضية وجودة البيانات

## 📌 أولاً: الخلاصة المركزة للشخص الثاني (Cheat Sheet)
- **مهمتك:** استعراض عملية تنظيف البيانات وتطبيق القواعد الفيزيائية للأفعال الستة، المفاتيح البديلة (Surrogate Keys)، وضمان التوازن الرياضي (Reconciliation Gate بنسبة 100%).
- **الكلمات المفتاحية التي يجب أن ترددها:**
  `The 6 Core Verbs`, `Trim (NULLIF LTRIM RTRIM)`, `Standardize (UPPER)`, `Convert (TRY_CONVERT)`, `Deduplicate (ROW_NUMBER)`, `Quarantine & Validate`, `silver.reject_log`, `Surrogate Keys (INT IDENTITY)`, `Reconciliation Gate (100% Balanced)`.
- **أهم جملة تفتتح بها:**  
  *"أنا مستلم الداتا من زميلي في البرونز كبيانات خام غير موثوقة، ومسؤوليتي في الفضة هي تحويلها لـ Trusted Enterprise Data مطابقة للمنطق الفيزيائي والـ Data Quality Governance."*

---

## 🏛️ ثانياً: الفكرة الهندسية للجزئية (The Concept)
البيانات في البرونز تحتوي على:
- مسافات بيضاء زائدة (Trailing/Leading Whitespaces).
- نصوص وقيم مفقودة كفراغات (`''`).
- أنواع بيانات غير مدققة (نصوص بدل أرقام وتواريخ).
- احتمالية وجود صفوف مكررة أو صفوف غير منطقية فيزيائياً (شذوذ حراري أو سرعات خارقة).

**منهجية الحل:** تطبيق **الأفعال الستة (The 6 Core Verbs)** داخل معاملة ذرية (ACID Transaction)؛ بحيث لو نجحت كل القواعد تعتمد الداتا، ولو وجد أي صف غير صالح يُعزل فوراً في جدول `silver.reject_log` مع ذكر السبب.

---

## 🔍 ثالثاً: الشرح التفصيلي لعمل الشخص الثاني

### الأفعال الستة للتنظيف بالتفصيل والكود:

#### 1. التهذيب (Trim):
```sql
NULLIF(LTRIM(RTRIM(city_id_raw)), '')
```
*الشرح:* إزالة المسافات من اليمين واليسار، ولو كانت القيمة عبارة عن مسافات فقط أو نص فارغ تتحول إلى `NULL` صريح.

#### 2. التوحيد القياسي (Standardize):
```sql
UPPER(NULLIF(LTRIM(RTRIM(city_id_raw)), ''))
```
*الشرح:* توحيد كتابة النصوص لحروف كبيرة (مثلاً `ruh` تصبح `RUH`) لتوحيد مفاتيح الربط.

#### 3. التحويل الآمن للأنواع (Convert):
```sql
TRY_CONVERT(DATE, date_clean)
TRY_CONVERT(DECIMAL(5,2), temp_max_clean)
CASE WHEN LOWER(is_dust_clean) IN ('true', '1') THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
```
*الشرح:* استخدام `TRY_CONVERT` بدلاً من `CAST/CONVERT` لأنها ترجع `NULL` بهدوء في حال فشل التحويل بدلاً من كسر وتشغيل الـ Transaction Error.

#### 4. إزالة التكرارات (Deduplicate):
```sql
ROW_NUMBER() OVER (
    PARTITION BY city_id, weather_date 
    ORDER BY weather_date ASC
) AS rn
-- والاحتفاظ فقط بالنسخة الأولى: WHERE rn = 1
```
*الشرح:* تحديد التكرار بناءً على **مفتاح العمل الطبيعي (Natural Business Key)** وليس كامل الصف، والاحتفاظ بالنسخة الأصلية الأولى فقط.

#### 5. التحقق والعزل الصحي (Validate & Quarantine):
وضع قواعد الحدود الفيزيائية (Sanity Bounds):
- درجة الحرارة: بين -15°C و 65°C.
- سرعة المركبة: بين 0 و 250 كم/س.
- حرارة معالج GPU: بين 10°C و 115°C.
لو الصف خالف القواعد يُدرج في جدول المرفوضات:
```sql
INSERT INTO silver.reject_log (source_table, business_key, reject_reason, rejected_at)
SELECT 'silver.av_telemetry', telemetry_id, 'GPU temp exceeds 115C threshold', SYSDATETIME();
```

#### 6. الأمان المعاملي (Transaction Safety):
```sql
SET XACT_ABORT ON;
BEGIN TRANSACTION;
    -- تنفيذ عمليات الإدخال والتنظيف
COMMIT TRANSACTION;
```
*الشرح:* ضمان مبدأ الـ All-or-Nothing؛ فإذا حدث خطأ غير متوقع يتم التراجع التلقائي (Rollback) ولا تترك الطبقة في حالة متناقضة.

### المفاتيح البديلة والتوثيق (Surrogate Keys):
- تم إنشاء مفتاح بديل لكل جدول: `weather_key INT IDENTITY(1,1)`, `accident_key`, `telemetry_key`.
- إضافة عمود تاريخ الإنشاء المستودعي: `DW_create_date DATETIME2 DEFAULT SYSDATETIME()`.
- استخراج أبعاد زمنية مساعدة: `weather_year`, `weather_month`, `weather_day`.

### معادلة التوازن الرياضي (Reconciliation Gate):
$$\text{Bronze Rows} = \text{Silver Rows} + \text{Reject Log Rows} + \text{Duplicates}$$
- الطقس: $21,920 = 21,920 + 0 + 0 \quad \checkmark$
- الحوادث: $5,066 = 5,066 + 0 + 0 \quad \checkmark$
- التيليمتري: $12,000 = 12,000 + 0 + 0 \quad \checkmark$
- **الإجمالي:** $\mathbf{38,986} = \mathbf{38,986} + 0 + 0 \quad (\mathbf{100\% \text{ Balanced}})$

---

## 🗣️ رابعاً: السيناريو وطريقة الإلقاء أمام الدكتور (Script)

> **ابدأ بالثقة دي:**  
> "أنا مستلم الداتا من زميلي في البرونز يا دكتور، ومسؤوليتي في **الطبقة الفضية (Silver)** هي تطبيق معايير الحوكمة وجودة البيانات (Data Quality Governance) لتحويلها لـ **Trusted Enterprise Data**.
> 
> اتبعنا منهجية **الأفعال الستة (The 6 Core Verbs)**:
> 1. **Trim:** تنظيف المسافات الزائدة بدالة `NULLIF(LTRIM(RTRIM()))`.
> 2. **Standardize:** توحيد نصوص الأكواد بالحروف الكبيرة `UPPER()`.
> 3. **Convert:** التحويل الآمن بـ `TRY_CONVERT` للتواريخ والأرقام و `CASE WHEN` للمتغيرات المنطقية.
> 4. **Deduplicate:** حذف أي تكرار للمفتاح الطبيعي عبر الدالة التحليلية `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) = 1`.
> 5. **Validate & Quarantine:** فحص الحدود الفيزيائية (حرارة الطقس، سرعة السيارة، حرارة المعالج)، ولو في أي صف شاذ بيتعزل فوراً في جدول `silver.reject_log` مع ذكر سبب الرفض بالتفصيل.
> 6. **Transaction Safety:** العمليات محاطة بـ `BEGIN TRAN` مع تفعيل `SET XACT_ABORT ON` لضمان مبدأ الذرية.
> 
> وأضفنا مفاتيح بديلة مستقلة **Surrogate Keys** بـ `INT IDENTITY` لكل جدول وعمود تدقيق `DW_create_date`.
> وحققنا معادلة التوازن الرياضي (Reconciliation Gate) بنسبة **100%**: دخل 38,986 صفاً من البرونز، وخرج 38,986 صفاً نظيفاً في الفضة وصفر مرفوضات، والداتا جاهزة لتسليمها لزميلي في الذهب."

---

## ❓ خامساً: بنك أسئلة الدكتور للشخص الثاني
- **س1: ليه جدول `silver.reject_log` فاضي ومفيهوش صفوف مرفوضة؟**  
  *الإجابة:* كود العزل والفحص شغال ومكتوب بالكامل داخل الإجراء `silver.load_silver`؛ والجدول صفر لأن ملفات المصدر نظيفة بعد المعايرة. ولو قمنا بتجربة إدخال صف بدرجة حرارة 95°C الإجراء هيرميه فوراً في `reject_log`.
- **س2: ما الفرق بين `CONVERT` و `TRY_CONVERT`؟**  
  *الإجابة:* أمر `CONVERT` التقليدي إذا وجد نصاً لا يمكن تحويله يرمي Error ويوقف الـ Pipeline بالكامل. أما `TRY_CONVERT` فيرجع `NULL` بهدوء، مما يسمح للـ Pipeline بالاستمرار والتعامل مع القيمة لاحقاً.
- **س3: ليه استخدمتوا `ROW_NUMBER()` مش `DISTINCT`؟**  
  *الإجابة:* لأن `DISTINCT` تقارن كل أعمدة الصف بالكامل؛ إذا وجد اختلاف في عمود واحد لن تحذف التكرار. بينما `ROW_NUMBER()` تسمح لنا بالتحكم في مفتاح العمل الطبيعي (Natural Business Key) بدقة وعزل التكرارات الحقيقية.
- **س4: ما فائدة المفاتيح البديلة (Surrogate Keys) وليه ما نكتفيش بالمفتاح الطبيعي؟**  
  *الإجابة:* المفاتيح البديلة (`INT IDENTITY`) تعزل مستودع البيانات عن أي تغيرات قد تطرأ على مفاتيح الأنظمة المصدرية، وتسرع عمليات الفهرسة (Indexing) والربط (JOINs) في النماذج البعدية.

---

# 3. الشخص الثالث: مسؤول الطبقة الذهبية والنمذجة البعدية

## 📌 أولاً: الخلاصة المركزة للشخص الثالث (Cheat Sheet)
- **مهمتك:** مسك الختام والطبقة الأهم التي يتركز عليها تقييم الدكتور بالدرجات. شرح نموذج الـ Star Schema، مستوى دقة السجل (Grain)، كيفية حساب مؤشر الجاهزية (`av_readiness_score`)، والربط المعماري الكامل بين الذهب والفضة والبرونز.
- **الكلمات المفتاحية التي يجب أن ترددها:**
  `Dimensional Star Schema`, `Grain (One row per city per date)`, `4 Dimensions`, `Pre-aggregation CTEs`, `LEFT JOIN with ISNULL`, `Autonomous Readiness Index (av_readiness_score)`, `Operational Regimes (Optimal, Moderate, High Hazard)`, `Explainability over Black Box`.
- **أهم جملة تفتتح بها:**  
  *"يا دكتور، الذهب هو ثمرة المشروع كله؛ هنا بنحول البيانات الموثقة لنماذج بعدية بتخدم متخذي القرار ومؤشر ذكي بيحدد لغرف التحكم إمكانية تفعيل القيادة الذاتية لحظة بلحظة."*

---

## 🏛️ ثانياً: الفكرة الهندسية للجزئية (The Concept)
البيانات في الفضة مسطحة وموزعة في جداول منفصلة. دور الطبقة الذهبية هو:
1. **هندسة نموذج الأبعاد (Star Schema):** بناء جداول أبعاد مركزية وجدول حقائق موحد.
2. **تحديد مستوى الحبيبية (Grain):** صف واحد لكل مدينة في كل يوم تقويمي (`One row per city per date`) بإجمالي **21,920 صفاً**.
3. **التجميع المسبق (Pre-Aggregation):** تلخيص الحوادث والتيليمتري اليومية بواسطة CTEs قبل الربط.
4. **الربط الآمن بـ LEFT JOIN:** استخدام الطقس كأساس والربط مع الحوادث والتيليمتري بـ `LEFT JOIN` واستبدال القيم المفقودة بـ `ISNULL(..., 0)` للحفاظ على الأيام الآمنة.
5. **مؤشر الجاهزية التشغيلي اليومي:** خوارزمية هندسية واضحة ومفسرة (Explainable KPI) لتقييم السلامة من 0 إلى 100.

---

## 🔍 ثالثاً: الشرح التفصيلي لعمل الشخص الثالث

### 1. جداول الأبعاد الأربعة (Dimensions):
1. **`gold.dim_city` (10 صفوف):**
   - المفتاح: `city_key INT PRIMARY KEY`.
   - الخصائص: `city_id`, `city_name_en`, `city_name_ar`, `latitude`, `longitude`, `climate_zone`.
   - النطاقات المناخية: `DESERT_CONTINENTAL`, `COASTAL_HUMID_DUST`, `ARID_VALLEY_HEAT`, `HIGHLAND_TEMPERATE`, `NORTHERN_DESERT_PLATEAU`.
2. **`gold.dim_date` (2,192 صفاً):**
   - المفتاح: `date_key INT PRIMARY KEY` بصيغة `YYYYMMDD` (مثلاً `20240715`).
   - الخصائص: `calendar_date`, `year_number`, `month_number`, `month_name`, `quarter_number`.
3. **`gold.dim_weather_hazard`:**
   - المفتاح: `hazard_key`.
   - الخصائص: تصنيف كود WMO إلى مستويات خطورة على الحساسات (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`) وتأثيرها على الليدار والكاميرات.
4. **`gold.dim_av_failure_type`:**
   - المفتاح: `failure_type_key`.
   - الخصائص: تصنيف الأعطال الفرعية (`LIDAR_DUST_OCCLUSION`, `GPU_THERMAL_THROTTLING`, `TIRE_PRESSURE_BLOWOUT`, `CAMERA_SOLAR_BLINDING`).

### 2. جدول الحقائق المركزي (`gold.fact_daily_av_risk`):
- **الـ Grain:** `date_key + city_key` (مفتاح مركب فريد = 21,920 صفاً).
- **التجميع المسبق بواسطة CTEs:**
```sql
;WITH acc_agg AS (
    SELECT city_id, accident_date, COUNT(*) AS daily_accident_count, SUM(casualties_count) AS daily_casualties
    FROM silver.sa_traffic_accidents
    GROUP BY city_id, accident_date
),
tel_agg AS (
    SELECT city_id, telemetry_date, COUNT(*) AS daily_av_trips,
           SUM(CASE WHEN av_disengagement = 1 THEN 1 ELSE 0 END) AS daily_disengagements,
           AVG(lidar_attenuation_pct) AS avg_lidar_attenuation
    FROM silver.av_telemetry
    GROUP BY city_id, telemetry_date
)
```
- **الربط (JOIN Logic):**
  الربط الأساسي مع الطقس، ثم `LEFT JOIN acc_agg` و `LEFT JOIN tel_agg`.
  لو استخدمنا `INNER JOIN` كانت الأيام الخالية من الحوادث أو الاختبارات ستُحذف، ويفقد المستودع الحقيقة الأساسية!

### 3. معادلة مؤشر الجاهزية التشغيلي (`av_readiness_score`):
$$\text{Score} = 100 - (35 \times \text{Dust}) - (20 \times \text{Heat}) - (15 \times \text{Wind}) - (5 \times \text{Accidents}) - (8 \times \text{Disengagements})$$

```sql
ROUND(
    100.0
    - (CASE WHEN w.is_dust_storm = 1 THEN 35.0 ELSE 0.0 END)
    - (CASE WHEN w.is_extreme_heat = 1 THEN 20.0 ELSE 0.0 END)
    - (CASE WHEN w.max_wind_gusts_kmh > 50.0 THEN 15.0 ELSE 0.0 END)
    - (ISNULL(a.daily_accident_count, 0) * 5.0)
    - (ISNULL(t.daily_disengagements, 0) * 8.0)
, 2) AS av_readiness_score
```

### 4. تصنيف نطاقات التشغيل (ODD Regimes):
- **90 - 100 (Optimal):** تشغيل ذاتي كامل بدون قيود (ظروف مثالية).
- **60 - 89 (Moderate Risk):** تشغيل بحذر مع خفض السرعة وتفعيل حساسات الرادار والليدار المساندة.
- **أقل من 60 (High Hazard):** تعليق فوري للقيادة الذاتية وتسليم التحكم للسائق البشري (عواصف رملية أو حرارة قياسية).

---

## 🗣️ رابعاً: السيناريو وطريقة الإلقاء أمام الدكتور (Script)

> **ابدأ بالثقة دي:**  
> "أنا مسؤول يا دكتور عن **الطبقة الذهبية (Gold Layer)**، ودي الطبقة التحليلية الأهم اللي بتمثل المخرج النهائي لمستودع البيانات لدعم قرارات غرف التحكم وهيئات النقل.
> 
> صممنا الذهب وفق نموذج **Star Schema** احترافي بيتكون من:
> - **4 جداول أبعاد (Dimensions):**
>   1. `dim_city`: يضم المدن الـ 10 وإحداثياتها ونطاقها المناخي.
>   2. `dim_date`: يضم 2,192 يوماً تقويمياً فريداً مع تفاصيل التقويم.
>   3. `dim_weather_hazard`: يترجم أكواد الطقس الدولية WMO لمستويات خطورة على الحساسات.
>   4. `dim_av_failure_type`: يصنف أنماط أعطال الليدار والكاميرات والبطارية.
> - **جدول حقائق مركزي (Fact Table):** `gold.fact_daily_av_risk`
>   - **دقة السجل (Grain):** صف واحد لكل مدينة في كل يوم تقويمي (`One row per city per date`) بإجمالي **21,920 صفاً**.
>   - لخصنا بيانات الحوادث والتيليمتري مسبقاً بـ CTEs، واستخدمنا **LEFT JOIN مع ISNULL**؛ وده لأن مش كل يوم فيه حوادث أو تجارب AV، واستخدام INNER JOIN كان هيحذف الأيام الآمنة ويشوه الواقع الإحصائي تماماً!
> 
> وقمنا بحساب **مؤشر الجاهزية التشغيلي اليومي للمركبات الذاتية (Autonomous Readiness Index)** من 0 إلى 100:
> - العاصفة الترابية بتخصم 35 نقطة لأنها أخطر مهدد بيعطل الليدار والكاميرا في نفس الوقت.
> - الحرارة القصوى بتخصم 20 نقطة لاختناق المعالجات والبطاريات.
> - الرياح الشديدة 15 نقطة، وكل حادثة 5 نقاط، وكل انفصال للنظام 8 نقاط.
> 
> والمؤشر بيصنف الأيام لـ 3 نطاقات: مثالية (Optimal من 90 لـ 100)، متوسطة المخاطر (Moderate من 60 لـ 89)، وعالية الخطورة تمنع القيادة الذاتية (High Hazard أقل من 60).
> 
> وبكده حققنا قاعدة **'ما بُني على باطل فهو باطل'**؛ فالذهب دقيق وموثوق لأن الفضة نظفت وتحققت بنسبة 100%، والبرونز استوعب كافة البيانات بدقة."

---

## ❓ خامساً: بنك أسئلة الدكتور للشخص الثالث
- **س1: يعني إيه دقة السجل (Grain) في جدول الحقائق؟**  
  *الإجابة:* الـ Grain هو أدنى مستوى تفصيلي يمثله السطر الواحد في الجدول. الـ Grain عندنا هو: "سجل يومي لكل مدينة" (`One row per city per date`)، وإجمالي صفوفه 21,920 صفا (10 مدن × 2,192 يوماً).
- **س2: ليه عملتوا `LEFT JOIN` مش `INNER JOIN` مع الحوادث والتيليمتري؟**  
  *الإجابة:* لأن مش كل مدينة بيحصل فيها حادثة أو تجربة ذاتية كل يوم. لو عملنا `INNER JOIN` الجدول هيفقد كل الأيام الآمنة الخالية من الحوادث، وده هيدمر مؤشر الجاهزية! الـ `LEFT JOIN` مع `ISNULL` بيضمن الاحتفاظ بالأيام الهادئة وتسجيل صفر حوادث وصفر انفصالات.
- **س3: ليه بنيتوا مؤشر الجاهزية بمعادلة واضحة مش Machine Learning Model؟**  
  *الإجابة:* لأن أنظمة السلامة وإدارة المرور تتطلب **قابلية تفسير كاملة (Explainability)** للمسؤولين؛ يجب أن يعرف المشغل سبب تعليق القيادة الذاتية بدقة. الموديلات المعقدة غير مقبولة تشريعياً كمعيار سلامة مبدئي، لكن جهزنا مصفوفة بيانات في `gold.features_trip_telemetry` لتدريب نماذج Decision Trees و Clustering لاحقاً.
- **س4: ليه جدول `dim_av_failure_type` مش مربوط بـ Foreign Key مباشر في جدول الحقائق؟**  
  *الإجابة:* لأن مستوى دقة جدول الحقائق (Grain) هو يومي مجمع على مستوى المدينة بالكامل، بينما نمط العطل التفصيلي (`dim_av_failure_type`) مرتبط بالرحلة الفردية في الفضة (`silver.av_telemetry`). ومكانه التحليلي المناسب هو في View التنبؤ بالأعطال `gold.features_trip_telemetry`.

---

# 💻 كود العرض السريع على SSMS

شغل هذا الاستعلام الموحد أمام الدكتور لإثبات سلامة كافة الطبقات:

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

# 📋 جدول مطابقة طلبات الدكتور الـ 11

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
