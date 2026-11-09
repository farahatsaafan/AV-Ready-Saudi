# تقرير الطبقة الفضية (Silver Layer Report)

**المشروع:** AV-Ready-Saudi  
**المقرر:** مستودعات البيانات والتنقيب (Data Mining & Data Warehousing)  
**الطبقة:** Silver Layer (Cleansed, Typed, Deduplicated & Audited)  
**قاعدة البيانات:** `av_ready_saudi_dw`  
**الـ Schema المستهدف:** `silver.*`  

---

## 1. الهدف المعماري للطبقة الفضية (Architectural Objective)
تحويل البيانات الخام من طبقة البرونز إلى **بيانات مؤسسية موثوقة ومطابقة لقواعد الجودة (Trusted Enterprise Data)** من خلال:
1. فرض الأنواع الفيزيائية القوية (`DATE`, `INT`, `DECIMAL`, `BIT`).
2. إضافة مفاتيح بديلة للمستودع (`Surrogate Primary Keys`).
3. عزل وتوثيق أي صف غير مطابق في جدول الحجر الصحي `silver.reject_log`.
4. إضافة عمود التدقيق والتتبع الزمني `DW_create_date`.
5. ضمان التوازن الرياضي التام لقواعد البيانات (Reconciliation Gate).

---

## 2. منهجية الأفعال الستة للتنظيف (The 6 Core Verbs Execution)
طبق إجراء التحميل `silver.load_silver` المكتوب في `sql/02_silver.sql` الأفعال الستة التالية:

1. **التهذيب (Trim):** إزالة المسافات البيضاء الزائدة من البداية والنهاية عبر `NULLIF(LTRIM(RTRIM(col)), '')`.
2. **التوحيد والتقييس (Standardize):** تحويل النصوص لحروف كبيرة موحدة (`UPPER`) وتوحيد أكواد المدن والحالات.
3. **التحويل الآمن للأنواع (Convert):** استخدام دالة `TRY_CONVERT` للتحويل إلى `DATE`, `DECIMAL(5,2)`, `INT` لمنع انهيار الاستعلامات.
4. **إزالة التكرار (Deduplicate):** تطبيق دالة الترتيب النافذية `ROW_NUMBER() OVER (PARTITION BY [Natural_Keys] ORDER BY [Key] ASC)` والاحتفاظ بالإصدار الأول فقط (`rn = 1`).
5. **التحقق والحجر الصحي (Validate & Reject):** عزل الصفوف المخالفة للشروط المنطقية والفيزيائية داخل `silver.reject_log` مع تسجيل سبب الرفض بالتفصيل.
6. **الأمان المعاملي (Transaction Safety):** تغليف كافة عمليات التحويل في معاملة ذرية `BEGIN TRAN ... COMMIT / ROLLBACK` مع تفعيل `SET XACT_ABORT ON`.

---

## 3. إحصائيات الجداول الفضية وسجل الاستبعاد (Silver Tables & Reject Log)

| الجدول الفضي | المفتاح البديل (Surrogate Key) | المفتاح الطبيعي (Natural Key) | عدد الصفوف السليمة | عدد الصفوف المستبعدة |
| :--- | :--- | :--- | :---: | :---: |
| `silver.sa_weather` | `weather_key (INT IDENTITY)` | `date + city_id` | **21,920** | **0** |
| `silver.sa_traffic_accidents` | `accident_key (INT IDENTITY)` | `accident_id` | **5,066** | **0** |
| `silver.av_telemetry` | `telemetry_key (INT IDENTITY)` | `telemetry_id` | **15,000** | **0** |
| **`silver.reject_log`** | `reject_id (BIGINT IDENTITY)` | — | — | **0 مرفوضات** |

---

## 4. معادلة المطابقة والتوازن الرياضي (Mathematical Reconciliation Gate)
وفقاً للمعيار الإلزامي في شيتات اللاب وقالب الدكتور الرسمي:
$$\text{Bronze Rows} = \text{Silver Rows} + \text{Quarantined Rejects} + \text{Duplicate Rows}$$

### نتائج التحقق الإحصائي:
1. **الطقس (Weather):**
   $$21,920 \text{ (Bronze)} = 21,920 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad \checkmark \text{ [BALANCED]}$$
2. **حوادث الطرق (Accidents):**
   $$5,066 \text{ (Bronze)} = 5,066 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad \checkmark \text{ [BALANCED]}$$
3. **التيليمتري والأعطال (AV Telemetry):**
   $$15,000 \text{ (Bronze)} = 15,000 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad \checkmark \text{ [BALANCED]}$$

* **النتيجة الإجمالية:** خط الأنابيب متوازن بنسبة **100.0%** بدون أي فقدان للبيانات، وجاهز للبناء البعدي في الطبقة الذهبية.
