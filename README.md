# LoopWorth — Give Waste Another Worth

LoopWorth is an AI-assisted circular economy and electronic waste recovery platform. It connects customers, human administrators, certified recovery partners, and physical collection agents into an auditable, transparent 7-step waste recovery loop.

---

## The 7-Step Circular Economy Loop
1. **Item Submission**: Customer registers unused or damaged electronic items, provides condition descriptions, and uploads photos.
2. **AI Advisory Assessment (Agent 1)**: Inspects device attributes to recommend an advisory recovery route (`Reuse`, `Donate`, or `Recycle`).
3. **Route Confirmation & Preparation Plan (Agent 2)**: Customer confirms their preferred route; Agent 2 formulates packaging, data sanitization, and hazardous material precautions.
4. **Human Admin Review & Approval**: Administrator evaluates the preparation plan and approves, requests revisions, or rejects before partner matching is unlocked.
5. **Accredited Partner Matching (Agent 3)**: Evaluates pre-filtered certified recycling and charity partners; customer selects their preferred facility.
6. **Collection Logistics & Dispatch (Agent 4)**: Evaluates customer availability, partner operating hours, and agent territory to propose a pickup window; Administrator assigns the collection agent.
7. **Physical Collection & Completion**: Collection agent records item pickup (`Collected`) and delivery (`DeliveredToPartner`); Administrator confirms receipt and marks the cycle completed.

---

## Tech Stack
- **Backend**: .NET 8, ASP.NET Core Web API, Entity Framework Core 8, ASP.NET Core Identity, JWT Bearer Authentication, xUnit.
- **Frontend**: React 19, Vite 8, React Router 8, Axios, Lucide React (clean SVG icons, zero emojis), Inter typography.
- **Database**: PostgreSQL (Managed Neon instance supported, in-memory for testing).
- **AI Service**: Google Gemini REST integration (`gemini-2.0-flash`) with deterministic validation and anti-hallucination guardrails.

---

## Project Structure
```text
backend/
  LoopWorth.sln                 Master solution file
  src/
    LoopWorth.Domain/           Entities, string enums, domain constraints
    LoopWorth.Application/      DTOs, service interfaces, agent contracts
    LoopWorth.Infrastructure/   AppDbContext, Identity, Gemini Agents, DbInitializer
    LoopWorth.Api/              Controllers, middleware, JWT & CORS setup, Program.cs
  tests/
    LoopWorth.UnitTests/        Domain lifecycle and agent validation tests
    LoopWorth.IntegrationTests/ WebApplicationFactory and API endpoint tests

frontend/
  src/
    app/                        App shell and master router
    shared/                     Design system, global CSS, AuthContext, ApiClient, AppLayout
    modules/
      public/                   HomePage, LoginPage, RegisterPage
      items/                    Customer item submission and advisory assessment
      recovery/                 Recovery preparation plans and admin approval queue
      partners/                 Accredited partner matching and admin management
      collections/              Logistics scheduling, agent dispatch, and delivery
      dashboard/                Customer, Admin, and Collection Agent dashboards
      workflows/                Multi-agent execution trace and audit viewer

docs/
  architecture/
    system-architecture.md      High-level system topology and security model
    database-design.md          Complete entity data dictionary and ER diagram
    agentic-ai-workflow.md      Detailed agent prompt specifications and guardrails
```

---

## Quick Start Guide

### Prerequisites
- .NET 8 SDK (`8.0.x`)
- Node.js (`20.x` or higher) & npm

### 1. Run the Backend API
```bash
cd backend
dotnet restore LoopWorth.sln
dotnet build LoopWorth.sln
dotnet run --project src/LoopWorth.Api/LoopWorth.Api.csproj
```
The API starts at `http://localhost:5080` (Swagger documentation at `http://localhost:5080/swagger`).

### 2. Run the Frontend
```bash
cd frontend
npm install
npm run dev
```
The application will launch at `http://localhost:5173`.

---

## Demo Accounts
The system automatically seeds the following ready-to-test accounts upon startup:

| Role | Email | Password | Scope |
| :--- | :--- | :--- | :--- |
| **Admin** | `loopworthadmin@gmail.com` | `Admin123!` | Full platform administration, approvals, partner & fleet management, AI workflow audits |
| **Collection Agent** | `agent@loopworth.local` | `Agent123!` | Field driver portal, assigned pickup route, milestone updates (`Collected`, `Delivered`) |
| **Customer** | Sign up via `/register` or create new | Custom | Submit electronic waste, receive assessments, choose routes, select partners |

---

## Running Automated Tests
```bash
# Run all backend unit & integration tests
cd backend
dotnet test LoopWorth.sln

# Lint and build frontend
cd frontend
npm run lint
npm run build
```
