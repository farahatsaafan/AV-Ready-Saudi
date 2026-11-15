# 🌐 مصادر البيانات الرسمية والروابط المباشرة — AV-Ready-Saudi

> توثيق كامل ومفصل لجميع مصادر البيانات، روابط التحميل المباشرة، بوابات البيانات المفتوحة، والمواصفات الفنية لجميع الـ Datasets المستخدمة في المشروع.

---

## 1. 🌤️ بيانات الطقس (Weather Data)
* **اسم الملف في المشروع:** `Data/saudi_weather_daily_2019_2024.csv`
* **الحجم والبيانات:** 21,920 صف يغطي 10 مدن رئيسية في المملكة العربية السعودية على مدار 6 سنوات (2019 - 2024).
* **المتغيرات:** درجات الحرارة العظمى والصغرى، الأمطار، سرعة الرياح، كود حالة الطقس العالمي WMO.

### 🔗 روابط المصدر المباشرة:
1. **بوابة الأرشيف التفاعلية (Open-Meteo Historical Weather UI):**
   * [https://open-meteo.com/en/docs/historical-weather-api](https://open-meteo.com/en/docs/historical-weather-api)
   * *الشرح:* واجهة رسومية تفاعلية تمكنك من اختيار أي مدينة على خريطة المملكة وتحديد التاريخ (2019 - 2024) وتحميل الـ CSV مباشرة.
2. **رابط الاستدعاء المباشر بصيغة CSV (Direct API Call):**
   * [https://archive-api.open-meteo.com/v1/archive?latitude=24.7136&longitude=46.6753&start_date=2019-01-01&end_date=2024-12-31&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=Asia/Riyadh&format=csv](https://archive-api.open-meteo.com/v1/archive?latitude=24.7136&longitude=46.6753&start_date=2019-01-01&end_date=2024-12-31&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=Asia/Riyadh&format=csv)
   * *الشرح:* عند فتح هذا الرابط في المتصفح يقوم بتحميل ملف الـ CSV للطقس مباشرة وبشكل فوري بدون مفتاح API أو تسجيل دخول.
3. **مصدر نماذج الأقمار الصناعية ومحطات الرصد (ECMWF ERA5 Reanalysis):**
   * [https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels](https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels)
   * *الشرح:* المرجع المناخي العالمي التابع للمركز الأوروبي للتنبؤات الجوية (ECMWF) والمعتمد من منظمة الأرصاد العالمية.
4. **المركز الوطني للأرصاد بالمملكة العربية السعودية (NCM):**
   * [https://ncm.gov.sa/](https://ncm.gov.sa/)

---

## 2. 🚗 بيانات الحوادث المرورية (Traffic Accidents Data)
* **اسم الملف في المشروع:** `Data/saudi_traffic_accidents_2019_2024.csv`
* **الحجم والبيانات:** 5,066 سجل لحوادث الطرق السريعة في المملكة مقسمة حسب ممرات الطرق الوطنية الرئيسية (طريق 40، طريق 65، طريق 15، والمسارات الساحلية) على مدار 2019 - 2024.
* **المتغيرات:** شدة الحادث (Severity)، عدد المركبات المشتركة، عدد الإصابات والوفيات، حالة الرصيف، والعوامل البيئية المحيطة.

### 🔗 روابط المصدر المباشرة:
1. **بوابة البيانات المفتوحة الرسمية في المملكة العربية السعودية (Saudi Open Data Portal):**
   * [https://open.data.gov.sa/](https://open.data.gov.sa/)
   * *الشرح:* البوابة الوطنية الرسمية لحكومة المملكة للبيانات المفتوحة (تضم بيانات النقل والمرور والإحصاءات الحيوية).
2. **رابط مستودع بيانات حوادث المرور والإصابات حسب المناطق (KAPSARC Data Portal - Saudi Traffic Accidents):**
   * [https://data.kapsarc.org/explore/dataset/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/](https://data.kapsarc.org/explore/dataset/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/)
   * *رابط التنزيل المباشر الرسمي عبر API (Direct CSV Export):* [https://datasource.kapsarc.org/api/explore/v2.1/catalog/datasets/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/exports/csv](https://datasource.kapsarc.org/api/explore/v2.1/catalog/datasets/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/exports/csv)
   * *الشرح:* بوابة بيانات مركز الملك عبد الله للدراسات والبحوث (KAPSARC) الرسمية التي توفر التنزيل المباشر بصيغ CSV و JSON لمؤشرات الحوادث والإصابات والوفيات الصادرة عن الهيئة العامة للإحصاء (GASTAT).
3. **الهيئة العامة للإحصاء بالمملكة العربية السعودية (GASTAT):**
   * [https://www.stats.gov.sa/](https://www.stats.gov.sa/)
   * *الشرح:* نشرات إحصاءات السلامة المرورية وحوادث الطرق الدورية الرسمية.
4. **المعيار الدولي لتصادمات الطرق وحركية المركبات (UK Department for Transport - Road Safety Data):**
   * [https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-2023.csv](https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-2023.csv)
   * *الشرح:* المعيار القياسي الدولي المستخدم عالمياً لنمذجة فيزياء الاصطدام والظروف البيئية للطرق السريعة.

---

## 3. 🤖 بيانات القيادة الذاتية والأعطال (AV Disengagements & Telemetry)
* **اسم الملفات:**
  * `Data/av_telemetry_failures_saudi.csv` (12,000 صف)
  * `Data/saudi_av_sensor_dust_storm_failures.csv` (6,000 صف)
  * `Data/saudi_av_thermal_overheat_failures.csv` (6,000 صف)
  * `Data/saudi_av_tire_pressure_blowout_failures.csv` (6,000 صف)

### 🔗 روابط المصدر المباشرة:
1. **تقارير انفصال واختبارات القيادة الذاتية الرسمية (California DMV Autonomous Vehicles Portal):**
   * [https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/)
   * *الشرح:* البوابة الرسمية العالمية لسجلات شركات المركبات الذكية (Waymo, Cruise, Zoox, Apple) عن أسباب انفصال النظام الآلي وتدخل السائق البشري واختبارات الحساسات.
2. **بيانات الحساسات والتليماتري القياسية من مايكروسوفت (Microsoft Azure Predictive Maintenance):**
   * [https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv](https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)
   * [https://github.com/microsoft/sqlworkshops/blob/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv](https://github.com/microsoft/sqlworkshops/blob/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv)
   * *الشرح:* مستودع مايكروسوفت الرسمي لبيانات التليماتري والحساسات والأعطال الزمنية للمركبات.
3. **مستودع البيانات الكامل الموحد على Google Drive:**
   * [https://drive.google.com/drive/folders/1ehqYZj7pMf8gUf-10DxyHAhyGpUt86tH](https://drive.google.com/drive/folders/1ehqYZj7pMf8gUf-10DxyHAhyGpUt86tH)
   * *الشرح:* المجلد السحابي المعتمد للمشروع ويحتوي على كافة ملفات الـ CSV الستة كاملة والمضغوطة وجاهزة للتحميل المباشر.
