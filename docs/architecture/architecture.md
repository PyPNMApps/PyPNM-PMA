# PyPNM-PMA Core Architecture

## Overview

PyPNM-PMA (Profile Management Assistant) is an application in the PyPNMApps ecosystem that consumes **pypnm-docsis / PyPNM** measurement and decode capabilities to recommend (and optionally validate) **DOCSIS 3.1/4.0 OFDM/OFDMA modulation profiles** for a Service Group (SG) based on live plant conditions.

At a high level, PyPNM-PMA:

- Samples a **population of cable modems** within a Service Group.
- Collects and links measurements across multiple modems (each modem has its own PyPNM *Capture Group*).
- Derives candidate **Downstream OFDM** and **Upstream OFDMA** modulation profiles from RxMER/SNR and related telemetry.
- Evaluates candidates using a configurable **ChannelSimulator** (or faster analytic estimators when simulation is not required).
- Produces profile recommendations with a **score**, estimated throughput, and risk indicators (expected overhead, margins, and error probability).

## Goals

- Provide repeatable, data-driven modulation profile recommendations per Service Group.
- Scale safely with Service Group size via concurrent capture and analysis.
- Separate concerns cleanly:
  - capture orchestration
  - measurement normalization
  - profile generation
  - profile validation/scoring
  - outputs and persistence

## Non-Goals

- Acting as a CMTS configuration tool by default (initial releases generate recommendations and artifacts; pushing profiles to devices can be added later).
- Achieving bit-accurate PHY emulation for all silicon/CMTS implementations in v1 (v1 focuses on a pragmatic simulator and/or analytic scoring; higher fidelity can be added iteratively).

## Terminology

- **Service Group (SG):** Set of modems sharing common RF resources and CMTS service flows.
- **Capture Group (PyPNM):** A unit of concurrent PNM capture/collection for a single modem (e.g., DS RxMER, US SNR/RxMER, Channel Estimate, FEC summary).
- **Capture Service Group (PyPNM-PMA):** A higher-level orchestrator that schedules and coordinates multiple PyPNM Capture Groups across modems in a Service Group.
- **Transaction ID:** Unique identifier for an individual capture result and its associated files/metadata (per modem, per capture).

## High-Level Architecture

PyPNM-PMA is logically organized into five layers.

1) **Integration Layer**

- Imports PyPNM / pypnm-docsis modules for:
  - device discovery (when available)
  - capture execution
  - file retrieval and decoding
  - standardized models (device details, headers, analysis results)

2) **Orchestration Layer**

- Coordinates “many modems per Service Group” capture cycles.
- Controls concurrency, retries, and capture scheduling policies.

3) **Normalization & Feature Layer**

- Converts per-modem measurements into SG-level comparable features:
  - per-subcarrier MER/SNR (or aggregated bands)
  - impairment indicators (tilt, suckouts, group delay, in-channel ripple)
  - quality flags (invalid bins, missing samples, capture age)

4) **Profile Synthesis Layer**

- Generates one or more candidate modulation profiles for:
  - DS OFDM (profile per subcarrier / banded regions)
  - US OFDMA (profile per subcarrier / banded regions)
- Applies policy constraints:
  - target margin (MER/SNR headroom)
  - profile count limits
  - minimum/maximum QAM orders
  - guard/pilot regions and reserved carriers

5) **Validation & Scoring Layer**

- Scores candidates using:
  - analytic estimators (fast path)
  - ChannelSimulator (validation path)
- Produces:
  - expected throughput (raw and effective)
  - estimated overhead components
  - risk score (likelihood of errors or instability)
  - modem coverage score (how many modems are supported by the profile)

## Data Flow

### Capture Linking Model

PyPNM-PMA links multiple modem capture groups under a single Service Group capture session.

Example (conceptual):

- Capture_Service_Group(1)
  - Capture_Group_1 (CM-1 measurements) → transaction_id(s) for each captured file type
  - Capture_Group_2 (CM-2 measurements) → transaction_id(s) for each captured file type
  - Capture_Group_N (CM-N measurements) → transaction_id(s) for each captured file type

A single Service Group cycle may produce many transactions per modem (e.g., RxMER + Channel Estimate + FEC Summary). PyPNM-PMA treats each transaction as an immutable measurement artifact and builds derived features on top.

### High-Level Process Flow

1. **Select Modems**
   - Choose a representative sample of modems within the SG:
     - stratified by location/PHY type/vendor if known
     - include “good”, “median”, and “poor” performers where possible

2. **Execute Captures (Concurrent)**
   - For each modem: run PyPNM Capture Group(s) in parallel.
   - Collect transaction IDs and decoded outputs into a normalized working set.

3. **Compute SG Features**
   - Build SG-level views:
     - distribution of per-subcarrier MER/SNR (min/median/pXX)
     - impairment signatures across frequency
     - temporal stability if multiple capture windows exist

4. **Generate Candidate Profiles**
   - Derive profiles from features and policy constraints.
   - Produce 1..K candidates (for example: conservative, balanced, aggressive).

5. **Score Candidates**
   - Run analytic scoring for all candidates.
   - Optionally run ChannelSimulator for top candidates or when confidence is low.

6. **Output Artifacts**
   - Generate:
     - recommended profiles (machine-readable)
     - executive summary (human-readable)
     - traceability metadata (which captures/transactions informed the decision)

## Concurrency Model

### Capture_Service_Group

The Capture_Service_Group is responsible for running many Capture Groups concurrently without overloading the CMTS, the modems, or the host system.

Key behaviors:

- **Work partitioning:** one worker per modem capture group, with a bounded worker pool per SG.
- **Backpressure:** enforce maximum concurrent SNMP sessions and file transfers.
- **Retry policy:** per-modem retries with bounded exponential backoff, and per-SG failure tolerance.
- **Time windowing:** optional staggered capture schedules to reduce synchronized load.

Suggested components:

- `ServiceGroupCapturePlanner`  
  Determines which modems to sample, what to capture, and when.

- `ServiceGroupCaptureExecutor`  
  Runs capture tasks concurrently and collects results.

- `ServiceGroupCaptureIndex`  
  Maintains a mapping:
  `service_group_id → modem_id → { capture_type → transaction_id }`.

## Profile Synthesis

### Inputs

Candidate profile generation should consider (when available):

- DS OFDM:
  - RxMER per subcarrier (or per bin group)
  - channel estimate metrics (frequency response magnitude/phase, group delay)
  - FEC summary statistics (post-FEC behavior and stability cues)

- US OFDMA:
  - SNR/RxMER per subcarrier (if supported)
  - upstream impairment cues (ingress bursts, micro-reflections, tilt)
  - ranging stability and power headroom (optional, when available)

### Core Approach

1. Convert MER/SNR into an **achievable modulation order** per frequency region under a configured margin.
2. Smooth and band-limit to avoid profile “chatter” (excessive per-bin toggling).
3. Enforce DOCSIS constraints:
   - reserved carriers (pilots, PLC/NCP regions where applicable)
   - minimum region size / segmentation rules (configurable)
   - limited number of profiles and transitions
4. Emit profile definitions compatible with downstream usage (JSON artifacts and/or future CMTS translators).

### Profile Types

PyPNM-PMA may generate multiple profile strategies per SG:

- **Conservative:** prioritizes stability (higher margin, lower QAM in weak regions)
- **Balanced:** aims for best overall throughput under a moderate error target
- **Aggressive:** maximizes throughput; used only when validation indicates acceptability

## Candidate Validation

### Analytic Scoring (Fast Path)

Analytic scoring should estimate:

- Bits per subcarrier (bpsc) from modulation order
- Gross throughput from:
  - subcarrier count, symbol rate, cyclic prefix assumptions
- Effective throughput from:
  - FEC rate assumptions (LDPC/BCH)
  - pilot/reserved carrier overhead
  - framing / scheduler overhead (configurable approximation)

Outputs:

- `throughput_raw_bps`
- `throughput_effective_bps`
- `coverage_score` (fraction of sampled modems meeting margin)
- `risk_score` (derived from low-percentile MER/SNR and instability cues)

### ChannelSimulator (Validation Path)

The ChannelSimulator provides additional confidence by simulating profile performance through a parameterized channel model derived from measured conditions.

#### Responsibilities

- Create a pseudo-byte stream as payload input.
- Map bits into symbols according to the candidate modulation profile.
- Apply OFDM/OFDMA framing assumptions:
  - frequency-domain mapping
  - pilot/reserved carrier handling (configurable)
  - optional frequency interleaving/scrambling
- Apply FEC:
  - LDPC with an assumed code rate (configurable)
  - optional BCH outer code approximation (configurable)
- Pass through a noisy channel model driven by SG conditions:
  - AWGN baseline from MER/SNR
  - optional frequency-selective fading based on channel estimate magnitude
  - optional phase noise / group delay influence (configurable, incremental)
- Produce performance metrics.

#### Outputs

- `bler` / `cw_error_rate` (as implemented)
- `estimated_post_fec_error_probability`
- `effective_throughput_bps` (including configured overhead)
- `score` with traceability (inputs and assumptions)

## Scoring and Decision Policy

Candidate ranking should be policy-driven and transparent. A recommended default policy:

1. Reject candidates exceeding an error threshold (analytic or simulated).
2. Among remaining candidates:
   - maximize effective throughput
   - break ties by lower risk score and higher modem coverage

All scoring decisions should emit a rationale summary:

- margin used
- key limiting frequency regions
- which modems were worst-case drivers
- confidence level (analytic-only vs simulated)

## Outputs and Artifacts

PyPNM-PMA should produce a self-contained set of artifacts per SG cycle:

- `service_group_summary.json`
  - input capture references (transaction ids)
  - selected modems and sampling metadata
  - profile candidates + scores
  - recommended profile(s)

- `profile_<strategy>.json`
  - explicit per-region modulation map
  - derived assumptions (margin, constraints)

- `service_group_report.md` (optional)
  - human-readable summary
  - plots/figures references (if generated externally)

## Extensibility Notes

- Add vendor/CMTS translation layers later (profile JSON → vendor CLI/SNMP/NETCONF representations).
- Add temporal learning:
  - compare today’s SG signature to previous baselines
  - avoid profile oscillation unless a persistent shift is observed
- Add incremental channel models:
  - ingress burst models for upstream
  - micro-reflection models from impulse response / group delay cues

## Risks and Mitigations

- **Sampling bias:** A small modem sample may miss worst-case paths.
  - Mitigation: stratified sampling + include known “edge” modems.

- **Overfitting to a snapshot:** Profile may be optimal for a single window only.
  - Mitigation: use multiple captures over time and require stability.

- **Simulation complexity:** Full PHY simulation can be expensive.
  - Mitigation: analytic scoring first; simulate only top candidates or uncertain cases.

## Initial Implementation Milestones

1. Implement Capture_Service_Group orchestration and transaction linking.
2. Normalize RxMER/SNR and compute SG-level features.
3. Generate a conservative and balanced profile candidate per SG.
4. Implement analytic scoring and output artifacts.
5. Add ChannelSimulator validation for top candidates and confidence scoring.


