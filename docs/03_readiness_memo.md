# Technical Memo: Data Readiness for Mining

* **Project**: AV-Ready-Saudi (Autonomous Vehicle Operations in Saudi Arabia)
* **Date**: October 25, 2026
* **Assessment Scope**: Evaluation of Bronze vs. Silver transformations and analytical safety
* **Author**: Engineering Lead / Data Mining Team
* **Deliverable Reference**: Unit 1, Unit 2 & Unit 3 Readiness Defense

---

## 1. Executive Decision
### **STATUS: READY FOR DATA MINING (WITH DOCUMENTED SENSOR CONSTRAINTS)**

The ingested datasets have successfully transitioned from the permissive, untyped **Bronze** layer to the strongly-typed, validated, and deduplicated **Silver** layer. All quality gates, transactional commits, and reconciliation checks satisfy the mathematical criterion $\text{Bronze} = \text{Silver} + \text{Rejected} + \text{Duplicates}$.

The **Gold** feature store (`gold.vw_av_mining_features`) and hazard dimensions link all 3 core sources (`silver.sa_weather`, `silver.sa_traffic_accidents`, `silver.av_telemetry`) for downstream clustering, classification, and rule-mining algorithms.

---

## 2. Empirical Quality Evidence & Measurement

| Quality Metric Dimension | Measurement Rule | Observed Bronze State | Silver Resolution / Action | Outcome Status |
| :--- | :--- | :--- | :--- | :---: |
| **Completeness** | Non-null check on required keys (`city_id`, `date`) | String representations, potential whitespace | Missing optional attributes mapped to `NULL`; mandatory intact | **PASSED** (100% core completeness) |
| **Consistency** | Canonical string casing & formatting | Mixed casings and whitespace in city, road, severity | Standardized with `TRIM`, `UPPER`, and canonical codes | **PASSED** (Uniform domain codes) |
| **Accuracy / Validity** | Sensor validity domains: $-10^\circ\text{C} \le \text{temp} \le 65^\circ\text{C}$; speed $\ge 0$ | Raw text representations | Converted via `TRY_CONVERT`; invalid values quarantined to `reject_log` | **PASSED** (Physical boundaries respected) |
| **Uniqueness** | Distinct business key checks | Raw CSV files preserved verbatim | Validated via `ROW_NUMBER() OVER (...)` window filter | **PASSED** (0 duplicate records retained) |

---

## 3. Reconciliation Proof
As required by Unit 3 Lab 4, the data pipeline balance was mathematically proven in script `sql/quality/02_silver_reconciliation.sql`:

$$\begin{aligned}
\text{Weather: } 21,920 \text{ (Bronze)} &= 21,920 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad &\checkmark \text{ BALANCED} \\
\text{Accidents: } 5,066 \text{ (Bronze)} &= 5,066 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad &\checkmark \text{ BALANCED} \\
\text{Telemetry: } 15,000 \text{ (Bronze)} &= 15,000 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad &\checkmark \text{ BALANCED}
\end{aligned}$$

---

## 4. Key Unresolved Environmental Risks & Mining Recommendations
1. **Dust & Sandstorm Sensor Blindness**:
   * *Evidence*: Over 1,598 recorded LiDAR dust occlusion incidents and high PM10 atmospheric scattering events.
   * *Risk*: Complete LiDAR beam absorption and loss of 3D point cloud validity.
   * *Proposed Mining Task*: Implement a **Decision Tree Classifier** or **Random Forest** on `gold.vw_av_mining_features` to predict `av_disengagement` based on wind gusts, solar radiation, and extreme heat flags.
2. **Thermal Degradation in Summer Months**:
   * *Evidence*: Ambient temperatures routinely peak above 45°C in Riyadh, Dammam, and Buraidah, driving GPU compute temperatures up to 78.2°C.
   * *Risk*: On-board AI compute thermal throttling and battery degradation.
   * *Proposed Mining Task*: **K-Means Clustering ($K=3$)** to segment Saudi cities and months into three autonomous operational tiers: *Optimal Driving Conditions*, *Moderate Environmental Risk*, and *High Hazard / Restricted Operations*.
