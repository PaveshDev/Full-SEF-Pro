# LoopWorth Agentic AI Workflow & Guardrails

## 1. Multi-Agent Design Overview
LoopWorth orchestrates four distinct domain-specific agents, each scoped with strict input validation, deterministic pre-filtering, and structured output parsing.

```
[Customer Item Submission]
             |
             v
  +-----------------------+
  |        Agent 1        |
  | Item Assessment Agent |  --> Advisory: ConditionLevel, RecommendedRoute, Confidence
  +-----------------------+
             |
             v
[Customer Confirms / Selects Route]
             |
             v
  +--------------------------+
  |         Agent 2          |
  | Recovery Planning Agent  |  --> Preparation Steps, Safety Notes, Partner Type
  +--------------------------+
             |
             v
[Human Admin Review & Approval Gate]
             | (Approve / Revision / Reject)
             v
  +--------------------------+
  |         Agent 3          |
  |  Partner Matching Agent  |  --> Pre-filtered Candidate Ranking & Turnaround Rationale
  +--------------------------+
             |
             v
[Customer Selects Partner & Pickup Preference]
             |
             v
  +--------------------------+
  |         Agent 4          |
  | Collection Planner Agent |  --> Proposed Pickup Window & Suggested Agent
  +--------------------------+
             |
             v
[Human Admin Dispatch & Assign Gate]
             |
             v
[Collection Agent Field Delivery & Completion]
```

## 2. Detailed Agent Specifications

### Agent 1: Item Assessment Agent (`IItemAssessmentAgent`)
- **Objective**: Evaluates device condition and recommends an advisory route (`Reuse`, `Donate`, `Recycle`).
- **Inputs**: Item name, category, brand, model, customer-provided condition description, photo presence.
- **Output Schema**:
  ```json
  {
    "conditionLevel": "Good | Fair | Poor | Unknown",
    "recommendedRoute": "Reuse | Donate | Recycle",
    "alternativeRoute": "Reuse | Donate | Recycle",
    "confidenceLevel": "Low | Medium | High",
    "explanation": "Rationale based on physical and operational indicators"
  }
  ```
- **Guardrails**: Advisory only; the customer retains full autonomy to confirm or select an alternate recovery route before proceeding.

### Agent 2: Recovery Planning Agent (`IRecoveryPlanningAgent`)
- **Objective**: Formulates safe preparation, packaging, data sanitization, and hazard management instructions tailored to the chosen route.
- **Inputs**: Item details, category, confirmed route, prior assessment results.
- **Output Schema**:
  ```json
  {
    "suitability": "High | Medium | Low",
    "summary": "Preparation summary",
    "preparationSteps": ["Step 1", "Step 2"],
    "safetyNotes": ["Safety note 1", "Safety note 2"],
    "requiredPartnerType": "Certified E-Waste Recycler | Electronics Refurbisher | Charity"
  }
  ```
- **Human Gate**: The customer submits the plan to the human Administrator, who must explicitly Approve, Reject, or Request Revision before the pipeline continues.

### Agent 3: Partner Matching Agent (`IPartnerMatchingAgent`)
- **Objective**: Evaluates and ranks accredited partner organizations to fulfill the recovery request.
- **Pre-Filtering Guardrail**: Only active partners who support the item's category and recovery route are supplied as candidates.
- **Anti-Hallucination Rule**: The agent's output is checked against the pre-filtered candidate IDs. Any ID not present in the candidate set is strictly rejected.
- **Output Schema**:
  ```json
  [
    {
      "partnerId": "exact-guid-from-candidates",
      "rank": 1,
      "reason": "Accredited recycler in Colombo with shortest processing turnaround"
    }
  ]
  ```
- **Fallback**: If the model is unavailable, deterministic ranking by lowest average processing days and territory proximity takes over.

### Agent 4: Collection Planning Agent (`ICollectionPlanningAgent`)
- **Objective**: Coordinates customer availability, partner operating hours, and active collection agent service areas to propose an optimal pickup schedule.
- **Pre-Filtering Guardrail**: Only collection agents whose profiles are `IsActive == true` and `IsAvailable == true` are submitted as candidates.
- **Anti-Hallucination Rule**: Any suggested collection agent User ID is verified against the candidate list.
- **Output Schema**:
  ```json
  {
    "suggestedDate": "YYYY-MM-DD",
    "suggestedStartTime": "HH:MM",
    "suggestedEndTime": "HH:MM",
    "suggestedCollectionAgentId": "exact-user-id-from-candidates",
    "reason": "Agent operates in the customer's territory and pickup aligns with partner intake hours"
  }
  ```
- **Human Gate**: The proposed plan is reviewed by the Administrator, who retains final authority to assign the collection agent and dispatch the job.

## 3. Resilience and Auditing
- Every agent invocation creates or updates an `AgentWorkflow` record with an `AgentWorkflowStep` capturing `AgentName`, `StepName`, `ExecutionStatus` (`Running`, `Succeeded`, `Failed`), input summary, structured output summary, and error message.
- Administrators have complete real-time visibility into the audit trail via the AI Workflows portal (`/admin/workflows`).
