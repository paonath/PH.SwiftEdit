# Rules: Workflow 04 — Domain Expert Enrollment & Distributed Research

1. **Per-TOPIC Execution**:
   - The Guided Reasoning Orchestrator SHALL execute Workflow 04 for every `TOPIC-NN` defined in `proposal.md`.
2. **Proactive Dual-Directory Cache-Recall (`specs/agents/` & `openspec/agents/`)**:
   - WHEN resolving domain experts, the Guided Reasoning Orchestrator SHALL scan both `specs/agents/*.agent.md` and `openspec/agents/*.agent.md` with active `spec_root` precedence and emit a diagnostic warning on secondary directory loads.
3. **Mandatory Topic Domain Representation**:
   - The Guided Reasoning Orchestrator SHALL enroll at least one domain expert per `TOPIC-NN` ($N_{domain} \ge 1$) excluding `cyber-security-expert` (stack experts, stored `.agent.md` profiles, or polymorphic `domain-expert`).
4. **Mandatory Stack & Security Enrollment**:
   - WHERE a topic touches `.NET`, Angular, Python, Shell, DDD, or OOP scope, the Guided Reasoning Orchestrator SHALL enroll the corresponding stack expert (`dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`, `ddd-expert`, or `oop-architecture-expert`).
   - WHERE a topic involves IT, software, APIs, databases, cloud, or automation, the Guided Reasoning Orchestrator SHALL enroll `cyber-security-expert` as auditor.
5. **Mandatory 2-Source Cross-Validation**:
   - The Enrolled Experts SHALL cross-validate every Hard Constraint across at least two independent authoritative sources while separating Verified Facts (with URLs) from Deductions.
6. **Web Research Persistence (`attachments/` + `INDEX.md`)**:
   - WHEN online `search_web` queries execute, the Guided Reasoning Orchestrator SHALL save findings in `attachments/web-research-topic-[id].md` and index them in `attachments/INDEX.md`.
7. **Dynamic On-Demand Enrollment Seam**: Across all workflows (01 to 11), the orchestrator or participating experts may dynamically enroll additional polymorphic `domain-expert` instances whenever unforeseen domain constraints emerge.
