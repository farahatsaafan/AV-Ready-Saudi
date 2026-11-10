# 🌐 مصادر البيانات الرسمية والروابط المباشرة — AV-Ready-Saudi

> توثيق كامل ومفصل لمصادر البيانات الستة، روابط التحميل المباشرة، وطريقة جمعها وتوليدها للمشروع.

---

## 1. 🌤️ بيانات الطقس (Weather Data)
* **اسم الملف في المشروع:** `Data/saudi_weather_daily_2019_2024.csv` (21,920 صف لـ 10 مدن سعودية).
* **المصدر وطريقة التجميع:** تم استدعاؤها وتحميلها مباشرة عبر واجهة برمجة التطبيقات (API) لأرشيف الطقس التاريخي التابع لـ **Open-Meteo** بالاعتماد على بيانات محطات الرصد ونماذج الأقمار الصناعية (ECMWF ERA5).

### 🔗 روابط المصدر المباشرة:
1. **واجهة الأرشيف التفاعلية (Open-Meteo Historical Archive UI):**
   * [https://open-meteo.com/en/docs/historical-weather-api](https://open-meteo.com/en/docs/historical-weather-api)
   * *(واجهة تتيح اختيار أي مدينة وتحديد السنوات 2019–2024 وتنزيل الـ CSV بضغطة زر)*.
2. **رابط تحميل CSV مباشر فوراً:**
   * [اضغط هنا لتحميل ملف CSV لطقس السعودية](https://archive-api.open-meteo.com/v1/archive?latitude=24.7136&longitude=46.6753&start_date=2024-01-01&end_date=2024-12-31&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=Asia/Riyadh&format=csv)

---

## 2. 🚗 بيانات الحوادث المرورية (Traffic Accidents Data)
* **اسم الملف في المشروع:** `Data/saudi_traffic_accidents_2019_2024.csv` (5,066 سجل حوادث).
* **المصدر وطريقة التجميع:** نظراً لأن بوابات البيانات الإحصائية الحكومية المحلية تفرض حظراً جغرافياً على بروتوكول HTTP خارج المملكة، فقد تم الاعتماد على **قاعدة بيانات تصادمات الطرق المفتوحة التابعة لوزارة النقل البريطانية (UK Department for Transport - Road Safety Data)** باعتبارها المعيار الأكاديمي الدولي المفتوح لدراسة فيزياء الحوادث وسرعات الطرق وخطورة الإصابات، مع إعادة مواءمتها وإسقاطها على ممرات الطرق السريعة الوطنية في المملكة (طريق 40 الرياض-مكة، طريق 65، والمسارات الساحلية).

### 🔗 روابط المصدر المباشرة:
1. **البوابة الرسمية المفتوحة لبيانات حوادث وتصادمات الطرق:**
   * [https://www.gov.uk/government/collections/road-safety-statistics](https://www.gov.uk/government/collections/road-safety-statistics)
2. **رابط تحميل CSV مباشر لبيانات التصادمات:**
   * [https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-2023.csv](https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-2023.csv)
3. **صفحة مستودع البيانات على البوابة المفتوحة data.gov.uk:**
   * [https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-accidents-safety-data](https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-accidents-safety-data)

---

## 3. 🤖 بيانات القيادة الذاتية والأعطال (AV Disengagements & Telemetry)
* **اسم الملفات:**
  * `Data/av_telemetry_failures_saudi.csv` (15,000 رحلة وحساس)
  * `Data/saudi_av_sensor_dust_storm_failures.csv` (6,000 عطل عواصف غبارية)
  * `Data/saudi_av_thermal_overheat_failures.csv` (6,000 عطل حراري للمعالجات والبطارية)
  * `Data/saudi_av_tire_pressure_blowout_failures.csv` (6,000 عطل ضغط وحرارة الإطارات)
* **المصدر وطريقة التجميع:** سيارات القيادة الذاتية (Level 3 إلى Level 5) قيد التجارب ولم يتم إطلاقها تجارياً بالكامل بعد؛ لذا يتم تدريب نماذج الذكاء الاصطناعي عالمياً عبر دمج:
  1. بيانات تليماتري الحساسات الصناعية المفتوحة من **Microsoft Azure / SQL Workshops**.
  2. تقارير انفصال النظام الذاتي وحوادث الاختبارات من **California DMV & UC Berkeley TIMS**.
  3. محاكاة فيزيائية لتدهور حساسات الليدار والكاميرات في العواصف الترابية ودرجات حرارة الصيف القصوى.

### 🔗 روابط المصدر المباشرة:
1. **البوابة الرسمية لحوادث وتقارير سلامة القيادة الذاتية (UC Berkeley TIMS & California DMV):**
   * [https://tims.berkeley.edu/tools/avsafety.php](https://tims.berkeley.edu/tools/avsafety.php)
2. **مستودع مايكروسوفت الرسمي على GitHub لبيانات التليماتري والحساسات:**
   * [صفحة الملف على GitHub لمايكروسوفت](https://github.com/microsoft/sqlworkshops/blob/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)
3. **رابط تحميل CSV مباشر لتليماتري الحساسات من مايكروسوفت (Raw CSV):**
   * [https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv](https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)

---

## 4. 📁 مجلد Google Drive للمشروع (المستودع الرئيسي الجاهز)
* [Google Drive — AV-Ready-Saudi Datasets](https://drive.google.com/drive/u/0/folders/1ehqYZj7pMf8gUf-10DxyHAhyGpUt86tH)
  * يضم الملفات الستة كاملة ومجهزة للمستودع بالإضافة إلى أرشيف `AV_Ready_Saudi_All_Datasets.zip` لتحميل كل شيء بضغطة زر واحدة.
