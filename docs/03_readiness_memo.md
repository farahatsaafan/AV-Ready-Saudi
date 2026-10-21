# Technical Memo: Data Readiness for Mining

* **Project**: AV-Ready-Saudi (Autonomous Vehicle Operations in Saudi Arabia)
* **Date**: October 21, 2026
* **Assessment Scope**: Evaluation of Bronze vs. Silver transformations and analytical safety
* **Author**: Engineering Lead / Data Mining Team
* **Deliverable Reference**: Unit 1 & Unit 2 Readiness Defense

---

## 1. Executive Decision
### **STATUS: READY FOR DATA MINING (WITH DOCUMENTED SENSOR CONSTRAINTS)**

The ingested datasets have successfully transitioned from the permissive, untyped **Bronze** layer to the strongly-typed, validated, and deduplicated **Silver** layer. All quality gates, transactional commits, and reconciliation checks satisfy the mathematical criterion $\text{Bronze} = \text{Silver} + \text{Rejected} + \text{Duplicates}$.

The **Gold** feature store (`gold.vw_av_mining_features`) and hazard dimensions are fully populated and validated for downstream clustering, classification, and rule-mining algorithms.

---

## 2. Empirical Quality Evidence & Measurement

| Quality Metric Dimension | Measurement Rule | Observed Bronze State | Silver Resolution / Action | Outcome Status |
| :--- | :--- | :--- | :--- | :---: |
| **Completeness** | Non-null check on required keys (`city`, `date`, `temp`) | 17 blank humidity entries; 0 blank temperatures | Missing optional attributes safely mapped to `NULL`; mandatory intact | **PASSED** (100% core completeness) |
| **Consistency** | Canonical string casing & formatting | Weather conditions had trailing spaces (`'Clear '`); humidity contained `%` | Standardized with `TRIM`, `UPPER`, and `%` removal | **PASSED** (Uniform domain codes) |
| **Accuracy / Validity** | Sensor validity domains: $-10^\circ\text{C} \le \text{temp} \le 65^\circ\text{C}$; visibility $\ge 0$ | Raw text representations | Converted via `TRY_CONVERT`; zero impossible outliers detected | **PASSED** (Physical boundaries respected) |
| **Uniqueness** | Distinct business key checks | Raw CSV files preserved | Validated via `ROW_NUMBER() OVER (...)` window filter | **PASSED** (0 duplicate records retained) |

---

## 3. Reconciliation Proof
As required by Unit 3 Lab 4, the data pipeline balance was mathematically proven in script `sql/quality/02_silver_reconciliation.sql`:

$$\begin{aligned}
\text{Weather: } 249,023 \text{ (Bronze)} &= 249,023 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad &\checkmark \text{ BALANCED} \\
\text{Accidents: } 168 \text{ (Bronze)} &= 168 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad &\checkmark \text{ BALANCED} \\
\text{Telemetry: } 389 \text{ (Bronze)} &= 389 \text{ (Silver)} + 0 \text{ (Rejected)} + 0 \text{ (Duplicates)} \quad &\checkmark \text{ BALANCED}
\end{aligned}$$

---

## 4. Key Unresolved Environmental Risks & Mining Recommendations
1. **Dust & Sandstorm Sensor Blindness**:
   * *Evidence*: Over 1,893 recorded dust storm hours and 1,501 fog hours in the dataset.
   * *Risk*: High probability of complete LiDAR attenuation and optical camera occlusion.
   * *Proposed Mining Task*: Implement a **Decision Tree Classifier** or **Random Forest** on `gold.vw_av_mining_features` to predict `av_operating_class` based on monthly wind speed, temperature peaks, and low visibility hours.
2. **Thermal Degradation in Summer Months**:
   * *Evidence*: Temperatures routinely peak above 48°C in Riyadh, Qassim, and Eastern Province.
   * *Risk*: On-board GPU/Compute thermal throttling and camera sensor noise.
   * *Proposed Mining Task*: **K-Means Clustering ($K=3$)** to segment Saudi cities into three autonomous operational tiers: *Year-Round Autonomous Capable*, *Seasonally Restricted*, and *High Hazard / Pilot Restricted*.
