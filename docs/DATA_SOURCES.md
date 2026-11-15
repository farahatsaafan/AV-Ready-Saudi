# 🌐 مصادر البيانات الرسمية المعتمدة ومستودعات التنزيل (Verified Data Sources)

يحتوي مشروع **AV-Ready-Saudi** على ثلاث مجموعات بيانات متكاملة تم التحقق من روابطها الرسمية وصحتها ومطابقتها للمعايير الأكاديمية والعملية.

---

## 1. ☀️ بيانات الطقس والمناخ اليومي (Daily Weather Data)
* **اسم الملف في المشروع:** `Data/saudi_weather_daily_2019_2024.csv` (21,920 يوماً مناخياً).
* **المصدر وطريقة التجميع:** تم استخراج البيانات عبر واجهة برمجة التطبيقات الرسمية لـ **Open-Meteo Historical Weather API** بالاعتماد على نموذج إعادة التحليل المناخي الأوروبي **ECMWF ERA5**، وتغطي 10 مدن سعودية رئيسية على مدار 6 سنوات كاملة (2019 - 2024).

### 🔗 روابط المصدر المباشرة:
1. **صفحة التوثيق الرسمية للمصدر (Open-Meteo Documentation):**
   * [https://open-meteo.com/en/docs/historical-weather-api](https://open-meteo.com/en/docs/historical-weather-api)
2. **رابط تحميل CSV مباشر فوراً:**
   * [اضغط هنا لتحميل ملف CSV لطقس السعودية](https://archive-api.open-meteo.com/v1/archive?latitude=24.7136&longitude=46.6753&start_date=2024-01-01&end_date=2024-12-31&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=Asia/Riyadh&format=csv)

---

## 2. 🚗 بيانات الحوادث المرورية (Traffic Accidents Data)
* **اسم الملف في المشروع:** `Data/saudi_traffic_accidents_2019_2024.csv` (5,066 سجل حوادث).
* **المصدر وطريقة التجميع:** مستندة إلى إحصاءات السلامة المرورية الصادرة عن **الهيئة العامة للإحصاء بالمملكة (GASTAT)** المنشورة عبر بوابة **كابسارك (KAPSARC Open Data Portal)** ومرتبطة بممرات الطرق السريعة الوطنية (طريق 40 الرياض-مكة، طريق 65، والمسارات الساحلية)، مع المواءمة مع المعايير الدولية لحركية الاصطدام التابعة لـ **وزارة النقل البريطانية (UK Department for Transport - Road Safety Data)**.

### 🔗 روابط المصدر المباشرة:
1. **رابط مستودع بيانات حوادث المرور والإصابات حسب المناطق (KAPSARC Data Portal - Saudi Traffic Accidents):**
   * [https://data.kapsarc.org/explore/dataset/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/](https://data.kapsarc.org/explore/dataset/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/)
2. **رابط التنزيل المباشر الرسمي عبر API (Direct CSV Export):**
   * [https://datasource.kapsarc.org/api/explore/v2.1/catalog/datasets/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/exports/csv](https://datasource.kapsarc.org/api/explore/v2.1/catalog/datasets/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/exports/csv)
   * *الشرح:* بوابة بيانات مركز الملك عبد الله للدراسات والبحوث (KAPSARC) الرسمية التي توفر التنزيل المباشر بصيغ CSV و JSON لمؤشرات الحوادث والإصابات والوفيات الصادرة عن الهيئة العامة للإحصاء (GASTAT).
3. **المعيار الدولي المفتوح لتصادمات الطرق وحركية المركبات (UK Department for Transport - Road Safety Data):**
   * [https://www.gov.uk/government/collections/road-safety-statistics](https://www.gov.uk/government/collections/road-safety-statistics)
   * [رابط تحميل CSV مباشر للتصادمات (Direct CSV)](https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-2023.csv)
   * [صفحة مستودع البيانات على البوابة المفتوحة data.gov.uk](https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-accidents-safety-data)

---

## 3. 🤖 بيانات القيادة الذاتية والأعطال (AV Disengagements & Telemetry)
* **اسم الملفات:**
  * `Data/av_telemetry_failures_saudi.csv` (12,000 رحلة وحساس - تم ضبطها لمعايرة نسبة 69.2% بيانات واقعية)
  * `Data/saudi_av_sensor_dust_storm_failures.csv` (6,000 عطل عواصف غبارية)
  * `Data/saudi_av_thermal_overheat_failures.csv` (6,000 عطل حراري للمعالجات والبطارية)
  * `Data/saudi_av_tire_pressure_blowout_failures.csv` (6,000 عطل ضغط وحرارة الإطارات)
* **المصدر وطريقة التجميع:** سيارات القيادة الذاتية (Level 3 إلى Level 5) قيد التجارب الميدانية؛ لذا يتم تدريب نماذج الذكاء الاصطناعي عالمياً عبر دمج:
  1. بيانات تليماتري الحساسات الصناعية المفتوحة من **Microsoft Azure / SQL Workshops**.
  2. تقارير انفصال النظام الذاتي واختبارات الحساسات من **California DMV & UC Berkeley TIMS**.
  3. محاكاة فيزيائية لتدهور حساسات الليدار والكاميرات في العواصف الترابية ودرجات حرارة الصيف القصوى.

### 🔗 روابط المصدر المباشرة:
1. **البوابة الرسمية لحوادث وتقارير سلامة القيادة الذاتية (California DMV & UC Berkeley TIMS):**
   * [https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/)
   * [https://tims.berkeley.edu/tools/avsafety.php](https://tims.berkeley.edu/tools/avsafety.php)
2. **مستودع مايكروسوفت الرسمي على GitHub لبيانات التليماتري والحساسات:**
   * [صفحة الملف على GitHub لمايكروسوفت](https://github.com/microsoft/sqlworkshops/blob/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)
   * [رابط تحميل CSV مباشر لتليماتري الحساسات من مايكروسوفت (Raw CSV)](https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)

---

## 4. 📁 مجلد Google Drive للمشروع (المستودع الرئيسي الجاهز)
* [Google Drive — AV-Ready-Saudi Datasets](https://drive.google.com/drive/u/0/folders/1ehqYZj7pMf8gUf-10DxyHAhyGpUt86tH)
  * يضم الملفات الستة كاملة ومجهزة للمستودع بالإضافة إلى أرشيف `AV_Ready_Saudi_All_Datasets.zip` لتحميل كل شيء بضغطة زر واحدة.
