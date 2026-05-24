# 19 – ivi-homescreen Evaluation: Spike Decision Framework

**Date:** 2026-05-24  
**Decision:** Go/No-Go für ivi-homescreen Runtime als Ersatz für Flutter Linux Runner  
**Owner:** Architecture / Spike Team  
**Status:** EVALUATION PENDING

---

## Executive Summary

Dieser Leitfaden definiert ein messbares Spike-Protokoll zur Bewertung, ob die ivi-homescreen Runtime + Plugins eine bessere UX für Carnine2 auf Raspberry Pi 4 liefern als der aktuelle Stack (Flutter Linux Runner + Rust gRPC).

**Entscheidungsregel:**
- **Go:** Gewichteter Score ≥ 4.0 UND kein Stop-Kriterium verletzt.
- **Conditional Go:** Score 3.4–3.99 mit Mitigationsliste.
- **No-Go:** Score < 3.4 ODER Stop-Kriterium verletzt.

---

## 1. Baseline: Aktueller Stack (Flutter Linux Runner)

### 1.1 Geschätzte Baseline-Werte

Basierend auf Flutter Linux Runner Standard + Rust gRPC über Unix-Socket. *(Messwerte eingeben beim Spike-Setup)*

| Metrik | Einheit | Erwarteter Wert | Gemessen* |
|--------|---------|---|---|
| p95 Touch-to-Action Latenz | ms | ~65–75 | `___ ms` |
| p99 Touch-to-Action Latenz | ms | ~90–110 | `___ ms` |
| Frame Rate (Navigation + 10Hz Telemetrie) | FPS | 58–60 | `___ FPS` |
| FPS 1%-Low (worst case) | FPS | 50–55 | `___ FPS` |
| Cold Start (bis interaktiv) | s | 2.5–3.2 | `___ s` |
| Backend-Disconnect Erkennung | ms | 600–800 | `___ ms` |
| CPU-Gesamt unter Last | % | 65–75 | `___ %` |
| RSS Memory (Frontend + Backend) | GB | 2.0–2.3 | `___ GB` |
| Uptime & Crashes (per 24h) | h | > 20 | `___ h` |

**\* Baseline-Spalte:** Während Spike-Setup am aktuellen Stack messen.

---

## 2. Messprotokoll: Workload-Szenen

### 2.1 Szene A: Navigation + Telemetrie (Standard Last)

**Setup:**
- Navigation UI aktiv (Karte sichtbar, keine Zoom/Pan-Gesten)
- Backend sendet Telemetrie @ 10 Hz (Speed, RPM, Temps)
- Dauer: 3 min stabil, dann Messungen

**Aktivitäten während Test:**
1. Alle 10 s eine Touch-Input (z.B. Settings-Button)
2. 2x Zoom/Pan-Geste
3. Laufende Telemetrie-Updates

**Zu messen:**
- p95/p99 Input Latenz (Touch-zu-Antwort)
- Frame Rate Median + 1%-Low
- CPU-Auslastung pro Prozess
- RAM RSS Frontend/Backend

**Werkzeuge:**
- `perf record` / `perf stat` für CPU
- `pidstat` für Pro-Prozess-Metriken
- `ps` / `top` für RAM
- Flutter DevTools für Frame-Timing

---

### 2.2 Szene B: Navigation + Medienwiedergabe

**Setup:**
- Navigation UI aktiv
- Audio/Video läuft parallel (lokal oder dummy-Stream)
- Gleiche Telemetrie wie Szene A

**Zu messen:**
- Gleich wie Szene A
- Zusätzlich: Audio-Dropout Rate, Video-Jitter

---

### 2.3 Szene C: Backend-Restart während UI

**Setup:**
- Navigation UI läuft stabil
- Backend `pkill carnine-backend` → sofort wieder starten
- UI läuft währenddessen weiter

**Zu messen:**
- Zeit bis UI visuell Error-Banner zeigt (500 ms Target)
- CPU/RAM während Reconnect
- Ob UI responsive bleibt oder hängt

---

### 2.4 Szene D: Kalter Start nach Boot

**Setup:**
- Pi neu gestartet
- Stoppuhr: SSH-Login bis Backend bereit und UI interaktiv

**Zu messen:**
- Time-to-Interactive (< 3 s Target)
- Backend Boot-Time
- UI Render-Zeit

---

## 3. Scoring-Tabelle: Basis + ivi-homescreen

### 3.1 Kriterium-Scoring

Skala: 5 = Excellent, 3 = Ok/Target, 1 = Critical Miss.

#### Kriterium 1: Input-Latenz (15% Gewicht)

| Score | p95 Latenz | Beschreibung |
|:---:|---|---|
| **5** | ≤ 50 ms | Ausgezeichnet, kaum wahrnehmbar |
| **4** | 51–65 ms | Gut, minimal wahrnehmbar |
| **3** | 66–80 ms | Akzeptabel, manchmal spürbar |
| **2** | 81–100 ms | Schwach, deutlich spürbar |
| **1** | > 100 ms | ❌ **STOP** – unbrauchbar |

**Baseline (Status quo):** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 2: Frame-Stabilität (15% Gewicht)

Messwert: FPS 1%-Low unter repräsentativer Last (Szene A).

| Score | FPS 1%-Low | Beschreibung |
|:---:|---|---|
| **5** | ≥ 60 FPS | Smooth, kein Stutter |
| **4** | 55–59 FPS | Größtenteils smooth |
| **3** | 50–54 FPS | Akzeptabel, selten wahrnehmbar |
| **2** | 45–49 FPS | Schwach, Stutter möglich |
| **1** | < 45 FPS | ❌ **STOP** – zu stotterig |

**Baseline:** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 3: Startzeit (10% Gewicht)

Messwert: Kalter Start (Szene D), Boot bis interaktiv.

| Score | Cold Start | Beschreibung |
|:---:|---|---|
| **5** | < 2.0 s | Sehr schnell |
| **4** | 2.0–3.0 s | Gut |
| **3** | 3.0–4.0 s | Akzeptabel |
| **2** | 4.0–5.0 s | Langsam |
| **1** | ≥ 5.0 s | Zu langsam |

**Baseline:** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 4: Backend-Resilienz (10% Gewicht)

Messwert: Disconnect-Erkennung (Szene C), von Fehler bis UI-Fehler-Banner.

| Score | Erkennung | Beschreibung |
|:---:|---|---|
| **5** | ≤ 300 ms | Augenblicklich |
| **4** | 301–500 ms | Gut (Target) |
| **3** | 501–900 ms | Akzeptabel |
| **2** | 901–1200 ms | Schwach |
| **1** | > 1200 ms | ❌ **STOP** – zu langsam |

**Baseline:** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 5: CPU-Headroom (10% Gewicht)

Messwert: Gesamt-CPU % unter Last (Szene A), avg über 3 min.

| Score | CPU Avg | Beschreibung |
|:---:|---|---|
| **5** | ≤ 60 % | Sehr komfortabel |
| **4** | 61–70 % | Gut |
| **3** | 71–75 % | Akzeptabel |
| **2** | 76–85 % | Knapp |
| **1** | > 85 % | ❌ **STOP** – Thermal/Throttle-Risiko |

**Baseline:** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 6: RAM-Headroom (10% Gewicht)

Messwert: RSS Memory Frontend + Backend, unter Last.

| Score | RSS | Beschreibung |
|:---:|---|---|
| **5** | ≤ 1.8 GB | Sehr komfortabel (4GB Pi) |
| **4** | 1.9–2.2 GB | Gut |
| **3** | 2.3–2.5 GB | Akzeptabel (tight) |
| **2** | 2.6–3.0 GB | Knapp |
| **1** | > 3.0 GB | ❌ **STOP** – Swap-Thrashing |

**Baseline:** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 7: Integrationsaufwand (15% Gewicht)

Messwert: Geschätzte Personen-Tage (PT) für MVP-Integration.

| Score | PT Estimate | Beschreibung |
|:---:|---|---|
| **5** | ≤ 5 PT | Plug & Play |
| **4** | 6–12 PT | Überschaubar |
| **3** | 13–15 PT | Vertretbar |
| **2** | 16–25 PT | Aufwändig |
| **1** | > 25 PT | ❌ **STOP** – zu teuer |

**Baseline:** `___ PT` (nicht zutreffend) | **ivi-homescreen:** `___ PT` Estimate

---

#### Kriterium 8: Wartbarkeit (10% Gewicht)

Bewertung: Zusätzliche Build-/Runtime-Komplexität durch neue Stacks.

| Score | Komplexität | Beschreibung |
|:---:|---|---|
| **5** | Minimal | Kaum neuer Code, bestehende Tools |
| **4** | Gering | Kleine neue Dependency |
| **3** | Mittel | Neue Technologien, aber dokumentiert |
| **2** | Hoch | 2+ neue Stacks, signifikant mehr Doku |
| **1** | Sehr Hoch | ❌ **STOP** – Team kann nicht sustain |

**Baseline:** `___ Punkte` | **ivi-homescreen:** `___ Punkte`

---

#### Kriterium 9: Security-Fitness (5% Gewicht)

Binär: Erfüllt LAN-only + TLS/Auth für Remote-Control (gemäß [10-quality-requirements.md](10-quality-requirements.md))?

| Score | Status | Beschreibung |
|:---:|---|---|
| **5** | ✅ Voll erfüllt | LAN-only, TLS, Auth-enforced |
| **3** | ⚠️ Mit Lücken | Teilweise implementierbar, braucht Workaround |
| **1** | ❌ Kritisch | Kann nicht erfüllt werden |

**Baseline:** `___ (ggf. Score)` | **ivi-homescreen:** `___ Score`

---

### 3.2 Gesamtscore-Berechnung

**Gewichtete Formel:**

```
Total_Score = 
    (Input_Latenz_Score × 0.15) +
    (Frame_Stabil_Score × 0.15) +
    (Startup_Score × 0.10) +
    (Resilience_Score × 0.10) +
    (CPU_Score × 0.10) +
    (RAM_Score × 0.10) +
    (Integration_Score × 0.15) +
    (Maintainability_Score × 0.10) +
    (Security_Score × 0.05)
```

**Beispiel-Rechnung:**

```
ivi-homescreen_Score = 
    (4 × 0.15) +      // Input Latenz: 4/5
    (4 × 0.15) +      // Frame Stabil: 4/5
    (3 × 0.10) +      // Startup: 3/5
    (4 × 0.10) +      // Resilience: 4/5
    (3 × 0.10) +      // CPU: 3/5
    (3 × 0.10) +      // RAM: 3/5
    (2 × 0.15) +      // Integration: 2/5 (aufwändig)
    (2 × 0.10) +      // Maintainability: 2/5 (mehr Komplexität)
    (5 × 0.05)        // Security: 5/5
  = 0.60 + 0.60 + 0.30 + 0.40 + 0.30 + 0.30 + 0.30 + 0.20 + 0.25
  = 3.25 / 5 = 3.25 → **Conditional Go mit Mitigationen**
```

**Dein Calculation Template:**

```
BASELINE:
Total = (___×0.15) + (___×0.15) + (___×0.10) + (___×0.10) + 
        (___×0.10) + (___×0.10) + (___×0.15) + (___×0.10) + (___×0.05)
      = ___ / 5

IVI-HOMESCREEN:
Total = (___×0.15) + (___×0.15) + (___×0.10) + (___×0.10) + 
        (___×0.10) + (___×0.10) + (___×0.15) + (___×0.10) + (___×0.05)
      = ___ / 5
```

---

## 4. Harte Stop-Kriterien (VETO)

Wenn **irgendein** dieser Punkte verletzt ist → **No-Go** (unabhängig von Score):

| Stop-Kriterium | Bedingung | Konsequenz |
|---|---|---|
| **Input Latency** | p95 > 80 ms | UX unbrauchbar für Touch-Driven App |
| **Frame Stability** | 1%-Low < 50 FPS | Stutter sichtbar, UX beeinträchtigt |
| **Disconnect Detect** | > 900 ms | User sieht Fehler zu spät, verwirrend |
| **Security** | LAN-only/TLS nicht erfüllbar | Compliance-Verstoß (10-quality-requirements) |
| **Integration Effort** | > 25 PT für MVP | Zu teuer, Team kann zeitlich nicht stemmen |

**Prüfliste vor Go/No-Go:**

- [ ] p95 Input Latenz ≤ 80 ms
- [ ] FPS 1%-Low ≥ 50 fps
- [ ] Disconnect-Erkennung ≤ 900 ms
- [ ] LAN-only + TLS für Remote erfüllbar
- [ ] Integration ≤ 25 PT Estimate

---

## 5. Entscheidungslogik

### 5.1 Go-Schwellen

| Gesamtscore | Entscheidung | Nächste Schritte |
|---|---|---|
| ≥ 4.0 | ✅ **Go** | Vollständige Migration planen; PoC in Produktion |
| 3.4–3.99 | ⚠️ **Conditional Go** | Mitigationsliste erarbeiten; noch 1–2 Wochen Detaildesign |
| < 3.4 | ❌ **No-Go** | Status quo beibehalten; evtl. einzelne Ideen klauen |

### 5.2 Veto-Logik

```
if ANY(stop_criteria_violated):
    Decision = NO-GO
    Reason = "Kritisches Stop-Kriterium verletzt"
else if score >= 4.0:
    Decision = GO
else if 3.4 <= score < 4.0:
    Decision = CONDITIONAL_GO
else:
    Decision = NO-GO
```

---

## 6. Messergebnis-Formular (zum Ausfüllen)

### Spike-Durchführung

**Datum Start:** `____`  
**Datum Ende:** `____`  
**Durchführer:** `____`  
**Hardware:** Raspberry Pi 4, `___ GB RAM`  
**OS:** Raspberry Pi OS `___ (Version)`  

### Baseline-Messungen (Status Quo)

```
Szene A – Navigation + Telemetrie (3× messen, Median):

  Lauf 1: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB
  Lauf 2: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB
  Lauf 3: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB
  ─────────────────────────────────────────────────────
  MEDIAN: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB

Szene D – Kalter Start:
  Lauf 1: ___ s
  Lauf 2: ___ s
  Lauf 3: ___ s
  MEDIAN: ___ s

Szene C – Disconnect-Erkennung:
  Lauf 1: ___ ms
  Lauf 2: ___ ms
  Lauf 3: ___ ms
  MEDIAN: ___ ms

Baseline-Gesamtscore: ___ / 5
```

### ivi-homescreen-Messungen (Prototype)

```
Szene A – Navigation + Telemetrie (3× messen, Median):

  Lauf 1: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB
  Lauf 2: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB
  Lauf 3: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB
  ─────────────────────────────────────────────────────
  MEDIAN: p95=___ ms,  FPS 1%-Low=___ FPS,  CPU=___% , RAM=___ GB

[Szene B, C, D gleich wiederholen]

Integration Effort Estimate: ___ PT (gRPC-Anbindung, Plugin-Build, Testing)
Team Assessment: Wartbarkeit neu? ___/5

ivi-homescreen-Gesamtscore: ___ / 5
```

### Stop-Kriterien-Prüfung

- [ ] **p95 Input Latency:** ___ ms ≤ 80 ms? ✅ / ❌
- [ ] **FPS 1%-Low:** ___ FPS ≥ 50 FPS? ✅ / ❌
- [ ] **Disconnect Detection:** ___ ms ≤ 900 ms? ✅ / ❌
- [ ] **LAN-only + TLS:** Erfüllbar? ✅ / ❌
- [ ] **Integration PT:** ___ PT ≤ 25 PT? ✅ / ❌

### ENTSCHEIDUNG

```
Baseline Score:          ___ / 5
ivi-homescreen Score:    ___ / 5
Improvement:             ___ Punkte

Stop-Kriterien OK?       ✅ / ❌
─────────────────────────────────────────────────

DECISION: 
  ☐ GO (Score ≥ 4.0 + alle Stop-Kriterien ok)
  ☐ CONDITIONAL GO (3.4–3.99 + Mitigations)
  ☐ NO-GO (< 3.4 oder Stop-Kriterium verletzt)

Begründung:
_________________________________________________________________________
_________________________________________________________________________
```

---

## 7. Interpretations-Leitfaden

### 7.1 "Go" Interpretation

**Score ≥ 4.0 + alle Stop-Kriterien ok:**
- ivi-homescreen ist nachweislich besser oder gleich.
- Integrationsaufwand rechtfertigt sich durch messbare Vorteile.
- **Aktion:** Volle Migration planen; PoC zu Produktion.
- **Risiko:** Moderat (messbar validiert).

### 7.2 "Conditional Go" Interpretation

**3.4–3.99 + Stop-Kriterien ok:**
- Marginale bis moderate Verbesserung.
- Integrationsaufwand ist vertretbar, aber signifikant.
- Könnte sich mittel- bis langfristig amortisieren.
- **Aktion:** 
  - 1–2 Wochen Detaildesign (gRPC-Anbindung, Plugin-Build, CI/CD)
  - Mitigation für schwächere Kriterien erarbeiten (z.B. Startup-Optimierung)
  - Nochmal messen mit Mitigationen
- **Risiko:** Mittel (möglich, aber unter Vorbehalt).

### 7.3 "No-Go" Interpretation

**< 3.4 oder Stop-Kriterium verletzt:**
- ivi-homescreen bringt nicht genug Mehrwert für die Komplexität.
- Oder: Kritische Anforderung kann nicht erfüllt werden.
- **Aktion:**
  - Status quo (Flutter Linux Runner) beibehalten.
  - Einzelne Best Practices von ivi-homescreen klauen (Logging, Packaging, CI/CD-Patterns).
  - Fokus auf Optimierung des aktuellen Stacks (gRPC-Tuning, Flutter-Profiling).
- **Risiko:** Niedrig (bewusst bewährter Weg).

---

## 8. Referenzen & Kontext

- **Quality Requirements:** [10-quality-requirements.md](10-quality-requirements.md) – Vollständige NFR-Liste
- **Deployment View:** [07-deployment.md](07-deployment.md) – Pi4 Hardware, Netzwerk, Sicherheit
- **Requirements & Constraints:** [01-requirements.md](01-requirements.md), [02-constraints.md](02-constraints.md)
- **ivi-homescreen Docs:** https://github.com/toyota-connected/ivi-homescreen (C++ Embedder)
- **ivi-homescreen-plugins:** https://github.com/toyota-connected/ivi-homescreen-plugins (nav_render_view, etc.)

---

## 9. Ergebnis-Dokumentation (nach Spike)

Nach Spike-Abschluss ausfüllen:

**Spike Decision Record (dieses Dokument oder separates ADR):**

```
Beschlossen: [Datum] → [Go / No-Go / Conditional Go]
Begründung: [1–2 Absätze, warum Entscheidung]
Messwerte: [Link zu Messergebnis-Formular ausgefüllt]
Mitigationen (falls Conditional Go): [Konkrete Maßnahmen]
Riskos / Open Items: [Was bleibt zu klären]
Nächste Reviews: [In 2 Wochen, nach Integration Beginn, ...]
```

---

**Ende Evaluations-Leitfaden**
