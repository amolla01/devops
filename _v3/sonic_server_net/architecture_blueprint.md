# Infrastructure Architecture Blueprint & Comparative Analysis

**Project Strategy:** Multi-Tenant OpenStack on Core Kubernetes (Nesting Architecture)  
**Deployment Phases:** Phase 1: Dallas (Primary Compute Core with Global Edge Acceleration) | Phase 2: Dhaka (Localized Regional Extension)

---

## 1. Executive Cost & Feasibility Study: Dallas vs. Bangladesh

To maintain an objective, equitable comparison, this financial model assumes a standard **42U rack drawing 5 kW of usable power** paired with a **10Gbps unmetered (flat rate) network blend**.

### 1.1 Financial Matrix

| Cost Element (Monthly Recurring) | Dallas, TX, USA (e.g., Infomart Hub) | Dhaka, Bangladesh (e.g., Local Tier III) |
| :--- | :--- | :--- |
| **42U Rack Space & 5 kW Power** | \$1,000 – \$2,100 | \$1,800 – \$2,500 |
| **10Gbps Unmetered Bandwidth** | \$500 – \$1,000 | \$2,500 – \$4,000+ |
| **Setup & Provisioning (One-time)** | \$500 – \$1,500 | \$1,000 – \$2,500 |
| **Total Estimated Monthly OPEX** | **\$1,500 – \$3,100** | **\$4,300 – \$6,500+** |

### 1.2 Core Cost Drivers & Structural Reality
*   **The Bandwidth Bottleneck:** In Dallas hubs like the Infomart, hundreds of Tier-1 carriers interconnect, making a dedicated 10Gbps flat-rate IP transit port highly commoditized. In Bangladesh, bandwidth is strictly divided between local internet exchange routing (**BDIX**) and international transit via submarine cables (**IIG**). Standard bundles include very low international bandwidth caps; scaling to a dedicated 10Gbps unmetered international pipe requires custom pricing and special regulatory approvals.
*   **Power and Infrastructure Overhead:** Texas features an independent electric grid with highly competitive commercial electricity rates (~10.2¢ per kWh) and lower Power Usage Effectiveness (PUE) ratings. While utility rates in Bangladesh seem lower on paper, grid instability forces local data centers to heavily invest in massive generator banks, UPS backups, and heavy-duty cooling units to combat ambient humidity. These capital costs are passed directly to consumers through strict per-amp pricing models.
*   **Tier Densities:** Dallas features an abundance of certified Tier III and Tier IV facilities. In Bangladesh, certified commercial Tier III facilities are scarce and space is tightly constrained, putting a luxury price premium on full 42U cabinets.

---

## 2. Core Target Architecture & Technology Stack

The platform utilizes a structured "nesting" design to isolate infrastructure operations from automated, self-service tenant environments.

