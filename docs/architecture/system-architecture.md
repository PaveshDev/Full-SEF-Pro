# LoopWorth System Architecture

## 1. Overview & Vision
**LoopWorth** ("Give Waste Another Worth") is an AI-assisted circular economy and electronic waste recovery platform. The system bridges individual customers, administrative reviewers, accredited recovery partners (recyclers, refurbishers, charitable donors), and physical collection logistics agents into a verifiable, audit-trailed workflow.

## 2. High-Level Architecture

```
+-------------------------------------------------------------------------+
|                              Web Frontend                               |
|                React 19 + Vite 8 + React Router 8                       |
|   (Customer Dashboard, Admin Portal, Collection Agent Field Interface)  |
+------------------------------------+------------------------------------+
                                     |
                          REST API (HTTPS / JSON)
                                     |
+------------------------------------+------------------------------------+
|                         ASP.NET Core 8 Web API                         |
|                                                                         |
|  [Controllers]                                                          |
|   - AuthController (JWT, ASP.NET Core Identity)                        |
|   - ItemsController (CRUD, photo handling, advisory triggers)          |
|   - RecoveryController (Preparation plans, human review decisions)     |
|   - PartnersController (Accredited recycler/charity matching)          |
|   - CollectionsController (Logistics scheduling & status lifecycle)    |
|   - CollectionAgentsController (Field fleet management)                |
|   - WorkflowsController (Agent execution audit history)                |
|                                                                         |
|  [AI Orchestration Services (Domain Guardrails & Mock Fallbacks)]       |
|   - ItemAssessmentAgent (Agent 1 - Condition & Route Advisory)         |
|   - RecoveryPlanningAgent (Agent 2 - Preparation & Safety Guidelines)  |
|   - PartnerMatchingAgent (Agent 3 - Candidate Pre-filter & Ranking)    |
|   - CollectionPlanningAgent (Agent 4 - Fleet Scheduling & Territory)   |
|                                                                         |
|  [Data Access Layer]                                                    |
|   - Single Unified AppDbContext (PostgreSQL / EF Core 8)               |
+-------------------+--------------------------------+--------------------+
                    |                                |
                    v                                v
+-------------------+---------------+   +------------+--------------------+
|      PostgreSQL Database          |   |   Google Gemini REST Model API  |
|     (Managed Neon Instance)       |   |    (gemini-2.0-flash endpoint)  |
+-----------------------------------+   +---------------------------------+
```

## 3. Project Structure & Responsibilities
- **`LoopWorth.Domain`**: Clean domain entities (`Item`, `RecoveryRequest`, `Partner`, `CollectionRequest`, `AgentWorkflow`), string enums (`RecoveryRoute`, `ItemStatus`, `RecoveryStatus`, `CollectionStatus`, `ConditionLevel`, `ConfidenceLevel`, `AgentExecutionStatus`), and domain constraints.
- **`LoopWorth.Application`**: Transport contracts (DTOs) and business service interfaces (`IItemAssessmentAgent`, `IRecoveryPlanningAgent`, `IPartnerMatchingAgent`, `ICollectionPlanningAgent`, `IFileStorageService`).
- **`LoopWorth.Infrastructure`**: EF Core `AppDbContext`, ASP.NET Core Identity (`ApplicationUser`), resilient Gemini REST agents with deterministic fallbacks, local file storage, and data seeder (`DbInitializer`).
- **`LoopWorth.Api`**: Web API host, middleware pipeline, JWT authentication, CORS policy, Swagger documentation, and controllers.
- **`frontend/`**: Single cohesive React 19 application with clean design tokens, role-based navigation, zero emojis, and full responsive views for Customer, Admin, and Collection Agent roles.

## 4. Security, Roles & Authentication
- Authentication is handled via standard JWT Bearer tokens signed with HMAC-SHA256.
- Three distinct roles:
  1. `Customer`: Can create items, upload photos, request advisory assessment, select routes, submit recovery plans, choose partners, and schedule pickups.
  2. `Admin`: Oversees platform health, reviews and approves/rejects recovery plans, manages partner organizations and collection fleet, assigns collection agents, and views AI workflow execution traces.
  3. `CollectionAgent`: Field interface to view assigned pickups, access customer and partner location information, and record status transitions (`Collected`, `DeliveredToPartner`).
- Strictly enforced ownership checks: Customers can only access their own items and recovery plans; collection agents can only update jobs assigned to their profile.
