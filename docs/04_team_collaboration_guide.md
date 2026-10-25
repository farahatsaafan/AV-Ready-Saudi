# دليل إعداد وتشغيل المشروع لفريق العمل (Team Setup & Collaboration Guide)

مرحباً بك في فريق عمل مشروع **AV-Ready-Saudi**! 
تم تصميم هذا الدليل لمساعدة أي عضو في الفريق على استنساخ المشروع وإعداده وتشغيل خط الأنابيب (Pipeline) بالكامل واستيراد البيانات خلال **أقل من 3 دقائق**.

---

## 1. المتطلبات الأساسية على جهازك
1. **Git** مثبت ومربوط بحسابك على GitHub.
2. **Microsoft SQL Server** (أي نسخة: Developer أو Express أو LocalDB) مع أداة **SSMS** أو `sqlcmd`.
3. حساب GitHub مع صلاحية الوصول لمستودع المشروع: `https://github.com/farahatsaafan/AV-Ready-Saudi.git`.

---

## 2. خطوات التشغيل خطوة بخطوة (Step-by-Step Setup)

### الخطوة 1: استنساخ المستودع (Clone)
افتح موجه الأوامر (PowerShell أو Git Bash) ونفذ:
```bash
git clone https://github.com/farahatsaafan/AV-Ready-Saudi.git
cd AV-Ready-Saudi
```

### الخطوة 2: تحميل حزمة البيانات الرسمية (Data Download)
نظراً للحجم الكبير لملفات البيانات التاريخية وحساسات القيادة الذاتية، يتم تحميلها من الرابط الرسمي الموحد:
* **رابط تحميل البيانات من Google Drive:** [تحميل حزمة البيانات المعتمدة AV-Ready-Saudi](https://drive.google.com/drive/folders/1ehqYZj7pMf8gUf-10DxyHAhyGpUt86tH)
* قم بفك ضغط الملفات داخل مجلد `Data/` في المشروع، ليكون الهيكل كالتالي:
  ```text
  AV-Ready-Saudi/Data/saudi_weather_daily_2019_2024.csv
  AV-Ready-Saudi/Data/saudi_traffic_accidents_2019_2024.csv
  AV-Ready-Saudi/Data/av_telemetry_failures_saudi.csv
  ```

---

## 3. تشغيل طبقات المعمارية وفق Medallion Architecture

يمكنك فتح وتنفيذ ملفات SQL بالترتيب الموضح أدناه عبر **SQL Server Management Studio (SSMS)** أو بالـ Terminal:

### أ) تهيئة الجداول وهياكل البيانات (DDL)
نفذ السكريبتات الموجودة في `sql/ddl/` بالترتيب:
1. `01_init_database.sql` (إنشاء قاعدة `av_ready_saudi_dw` وإنشاء الـ Schemas الخمسة).
2. `02_create_audit_tables.sql` (إنشاء جدول تتبع التدقيق `audit.load_log`).
3. `03_create_bronze_tables.sql` (إنشاء جداول الهبوط الخام للطبقة البرونزية).
4. `04_create_silver_tables.sql` (إنشاء الجداول الموثوقة وسجل الاستبعاد `silver.reject_log`).
5. `05_create_gold_views_tables.sql` (إنشاء جداول الأبعاد والحقائق ومصفوفة الـ Mining للطبقة الذهبية).

### ب) تشغيل العمليات التلقائية (Run Pipelines)
1. **تحميل طبقة Bronze:**
   ```sql
   USE av_ready_saudi_dw;
   EXEC bronze.load_bronze @base_path = 'D:\AV-Ready-Saudi\Data';
   ```
2. **تنظيف وتحويل طبقة Silver:**
   ```sql
   USE av_ready_saudi_dw;
   EXEC silver.load_silver;
   ```
3. **توليد الطبقة الذهبية ومؤشر الجاهزية:**
   ```sql
   USE av_ready_saudi_dw;
   EXEC gold.load_gold;
   ```

### ج) فحص ومطابقة الجودة (Quality Gates)
* نفذ السكريبت `sql/quality/01_bronze_validation.sql` للتأكد من مطابقة الصفوف (`MATCH`).
* نفذ السكريبت `sql/quality/02_silver_reconciliation.sql` للتأكد من التوازن الرياضي التام (`BALANCED`).

---

## 4. القواعد المتبعة لإدارة الفروع على Git (Git Workflow)

1. **دائماً اسحب آخر تحديثات من الفرع الرئيسي قبل العمل:**
   ```bash
   git pull origin main
   ```
2. **أنشئ فرعك الخاص أو استخدم فرعك المخصص:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **احفظ تغييراتك برسائل واضحة وموجزة:**
   ```bash
   git add .
   git commit -m "feat(module): describe what you built"
   git push origin feature/your-feature-name
   ```
4. **ممنوع نهائياً رفع ملفات البيانات الكبيرة (CSVs/PCD) على GitHub**؛ يتم الاعتماد دائماً على رابط Google Drive الرسمي.
