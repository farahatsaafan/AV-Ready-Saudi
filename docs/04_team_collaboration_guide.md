# دليل تشغيل المشروع لأعضاء الفريق (Team Setup & Collaboration Guide)

مرحباً بك في مشروع **AV-Ready-Saudi**! 🚗🇸🇦
تم تصميم هذا المشروع بحيث يستطيع أي زميل في الفريق تشغيل خط الأنابيب (Pipeline) بالكامل وقاعدة البيانات على جهازه في **أقل من 3 دقائق**.

---

## 1. المتطلبات الأساسية على جهازك
1. **Git** مثبت على جهازك.
2. **Microsoft SQL Server** (أي إصدار: Developer أو Express أو LocalDB) مع أداة **SSMS** أو `sqlcmd`.
3. حساب GitHub مضاف إليه صلاحية على المستودع.

---

## 2. خطوات التشغيل لأول مرة (Step-by-Step Setup)

### الخطوة 1: استنساخ المستودع (Clone)
افتح الـ Terminal (PowerShell أو Git Bash) ونفذ:
```bash
git clone https://github.com/farahatsaafan/AV-Ready-Saudi.git
cd AV-Ready-Saudi
```

### الخطوة 2: تحميل ملفات البيانات الأصلية (Data Download)
طبقاً لقواعد هندسة البيانات، الملفات الكبيرة غير مرفوعة على جيت هاب لمنع بطء التنزيل.
* **رابط جوجل درايف للبيانات:** [تحميل البيانات من Google Drive](https://drive.google.com/drive/folders/1TEnI7ki_svD5FSDBWtiwZdyROcEYpfDy?usp=drive_link)
* قم بتنزيل الملفات وضعها داخل مجلد `Data/` في المشروع بحيث يكون المسار:
  ```text
  AV-Ready-Saudi/Data/weather-sa-2017-2019-clean.csv
  AV-Ready-Saudi/Data/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008.csv
  AV-Ready-Saudi/Data/A2RL_IAC_prediction_annotations/a2rl_raw.csv
  ```

---

## 3. تشغيل قاعدة البيانات والـ Medallion Architecture

يمكنك فتح ملفات الـ SQL وتشغيلها بالترتيب من داخل برنامج **SQL Server Management Studio (SSMS)** أو تشغيلها عبر الـ Terminal مباشرة:

### أ) إنشاء قاعدة البيانات والطبقات (DDL)
نفذ السكربتات الموجودة في `sql/ddl/` بالترتيب:
1. `01_init_database.sql` (ينشئ قاعدة `av_ready_saudi_dw` والـ Schemas الخمسة).
2. `02_create_audit_tables.sql` (ينشئ جدول تتبع التحميل `audit.load_log`).
3. `03_create_bronze_tables.sql` (ينشئ جداول الـ Bronze النصية).
4. `04_create_silver_tables.sql` (ينشئ جداول الـ Silver والـ `reject_log`).
5. `05_create_gold_views_tables.sql` (ينشئ أبعاد وحقائق الـ Gold للتعدين).

### ب) تشغيل إجراءات التحميل (Run Pipelines)
1. **تحميل الـ Bronze:**
   ```sql
   USE av_ready_saudi_dw;
   EXEC bronze.load_bronze @base_path = 'مسار مجلد الداتا على جهازك';
   ```
2. **تشغيل تنظيف وتجهيز الـ Silver:**
   ```sql
   USE av_ready_saudi_dw;
   EXEC silver.load_silver;
   ```
3. **توليد بيانات الـ Gold وميزات الـ Mining:**
   ```sql
   USE av_ready_saudi_dw;
   EXEC gold.load_gold;
   ```

### ج) فحص الجودة والمطابقة (Quality Gates)
* شغل السكربت `sql/quality/01_bronze_validation.sql` للتأكد من وصول الصفوف (`MATCH`).
* شغل السكربت `sql/quality/02_silver_reconciliation.sql` للتأكد من معادلة التوازن (`BALANCED`).

---

## 4. القواعد الذهبية للعمل المشترك على Git (Git Workflow)

1. **قبل أن تبدأ كتابة أي كود جديد، اسحب أحدث التعديلات دائماً:**
   ```bash
   git pull origin main
   ```
2. **أنشئ فرعاً (Branch) جديداً لمهمتك:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **بعد الانتهاء واختبار الكود:**
   ```bash
   git add .
   git commit -m "وصف واضح للتعديل الذي قمت به"
   git push origin feature/your-feature-name
   ```
4. **افتح Pull Request على GitHub** ليقوم باقي التيم بمراجعته ودمجه في الـ `main`.
