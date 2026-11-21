#!/usr/bin/env python3
"""
Autonomous Scaffolding & Lifecycle Script for Guided Reasoning Flow Sessions.

Capabilities:
1. Mode A (New Session):
   - Auto-calculates next 3-digit prefix `[NNN]` in `reasoning/`.
   - Creates `reasoning/[NNN]_[slug]/` with `brief/` and `attachments/`.
   - Generates spec-oriented root files: `plan.md`, `proposal.md`, `design.md`, `task.md`.
   - Generates initial interview & convergence templates in `brief/`:
     `00-prompt-disambiguation-qa.md`, `consensus-matrix.md`, `tradeoffs-pro-cons.md`.
   - Copies external `--attachment` files into `attachments/` preserving original filename/content
     and populates `attachments/INDEX.md`.
2. Mode B (Rework / Revision Mode via `--rework-from`):
   - Performs fail-closed preventive backup into `attachments/history/rev-[REV]/`.
   - Migrates legacy `000-plan.md` to `plan.md` if present.
   - Parses inline `[[...]]` user annotations from prior `README.md` with line/section context.
   - Increments semantic revision (`1.0` -> `1.1`, `1.2`... or `--major` -> `2.0`).
3. Topic Expansion (`--init-topics` with `--session-dir`):
   - Expands `task.md` with per-TOPIC sub-checklists across Workflows 04 -> 08.
   - Scaffolds per-TOPIC templates in `brief/` (`topic-[id]-expert-activator-qa.md`,
     `topic-[id]-consensus.md`, `topic-[id]-human-review.md`).
"""

import argparse
import datetime
import json
import os
import re
import shutil
import sys
from pathlib import Path

RE_PREFIX = re.compile(r"^(\d{3})_")
RE_REV = re.compile(r"^rev-(\d{3})$")
RE_ANNOTATION = re.compile(r"\[\[(.*?)\]\]", re.DOTALL)


def sanitize_slug(slug: str) -> str:
    """Sanitize slug to contain only safe lowercase alphanumeric characters and hyphens."""
    slug = slug.strip().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug or "session"


def resolve_base_directory(base_dir: str | None) -> Path:
    """Resolve repository root safely against CWE-22."""
    return Path(base_dir).resolve() if base_dir else Path.cwd().resolve()


def resolve_agent_directories(repo_root: Path | None = None) -> tuple[dict[str, Path], list[str]]:
    """Scan and merge agent profiles from specs/agents/ and openspec/agents/ with active root precedence.

    Args:
        repo_root: Optional root directory of the repository (defaults to Path.cwd().resolve()).

    Returns:
        tuple containing:
        - dictionary mapping agent slug to resolved Path
        - list of diagnostic warning strings for agents resolved from secondary directory
    """
    root = Path(repo_root).resolve() if repo_root else Path.cwd().resolve()

    # Determine active spec root via .myspec.config.json or directory presence
    active_root = "openspec"
    config_file = root / ".myspec.config.json"
    if config_file.is_file():
        try:
            cfg = json.loads(config_file.read_text(encoding="utf-8"))
            if isinstance(cfg, dict) and "spec_root" in cfg:
                active_root = cfg["spec_root"]
        except Exception:
            pass
    else:
        specs_dir = root / "specs"
        openspec_dir = root / "openspec"
        if specs_dir.is_dir() and not openspec_dir.is_dir():
            active_root = "specs"

    primary_dir = root / active_root / "agents"
    secondary_root = "specs" if active_root == "openspec" else "openspec"
    secondary_dir = root / secondary_root / "agents"

    resolved_agents: dict[str, Path] = {}
    warnings: list[str] = []

    def _scan_dir(dir_path: Path) -> dict[str, Path]:
        agents: dict[str, Path] = {}
        if not dir_path.is_dir():
            return agents
        for entry in sorted(dir_path.iterdir()):
            if entry.is_file() and not entry.is_symlink() and entry.name.endswith(".agent.md"):
                slug = entry.name[:-len(".agent.md")]
                agents[slug] = entry.resolve()
        return agents

    primary_agents = _scan_dir(primary_dir)
    secondary_agents = _scan_dir(secondary_dir)

    for slug, p in primary_agents.items():
        resolved_agents[slug] = p

    for slug, p in secondary_agents.items():
        if slug not in resolved_agents:
            resolved_agents[slug] = p
            warnings.append(
                f"Agent '{slug}' loaded from secondary directory '{secondary_root}/agents/' "
                f"instead of active spec root '{active_root}/agents/'"
            )

    return resolved_agents, warnings


def validate_topic_domain_experts(experts: list[str]) -> tuple[bool, str]:
    """Verify that a topic enrolls at least one domain expert, excluding cyber-security-expert.

    Args:
        experts: List of expert identifiers assigned to the topic.

    Returns:
        tuple containing (is_valid, error_message).
    """
    if not experts:
        return False, "Topic must enroll at least one domain expert."

    non_sec = [e for e in experts if e != "cyber-security-expert"]
    if not non_sec:
        return (
            False,
            "Topic must enroll at least one domain expert (cyber-security-expert does not count toward the minimum).",
        )
    return True, ""




def _read_state_last_prefix(reasoning_dir: Path) -> int:
    """Read and validate last_prefix from reasoning/.second-brain-state.json.

    Args:
        reasoning_dir: Local ``reasoning/`` directory.

    Returns:
        Non-negative integer ``last_prefix`` (0 when the state file is absent).

    Raises:
        ValueError: If the state file is a symlink, contains invalid JSON, or has an invalid ``last_prefix``.
    """
    state_file = reasoning_dir / ".second-brain-state.json"
    if state_file.is_symlink():
        raise ValueError(f"Symlinked state file is forbidden (CWE-59): {state_file}")
    if not state_file.exists():
        return 0
    try:
        payload = json.loads(state_file.read_text(encoding="utf-8"))
    except Exception as err:
        raise ValueError(f"Malformed JSON in {state_file}: {err}") from err
    if not isinstance(payload, dict):
        raise ValueError(f"Invalid state payload object in {state_file}")
    raw_val = payload.get("last_prefix", 0)
    if isinstance(raw_val, bool) or not isinstance(raw_val, int) or raw_val < 0:
        raise ValueError(f"Invalid last_prefix '{raw_val}' in {state_file}")
    return raw_val


def _scan_dir_max_prefix(target_dir: Path | None) -> int:
    """Return the highest 3-digit directory prefix inside target_dir, or 0 if unreachable."""
    if target_dir is None or target_dir.is_symlink() or not target_dir.is_dir():
        return 0
    highest = 0
    for entry in target_dir.iterdir():
        if entry.is_dir() and not entry.is_symlink():
            match = RE_PREFIX.match(entry.name)
            if match:
                highest = max(highest, int(match.group(1)))
    return highest


def compute_next_prefix(reasoning_dir: Path, vault_reasoning_dir: Path | None = None) -> str:
    """Calculate max(NNN) + 1 across local reasoning/, state file, and optional SecondBrain vault.

    Args:
        reasoning_dir: Local repository ``reasoning/`` directory.
        vault_reasoning_dir: Optional SecondBrain ``50-Projects/<Repo>/reasoning/`` directory.

    Returns:
        Zero-padded 3-digit string for the next reasoning session prefix (e.g. ``"023"``).

    Raises:
        ValueError: If ``reasoning/.second-brain-state.json`` is symlinked or malformed.
    """
    state_max = _read_state_last_prefix(reasoning_dir) if reasoning_dir.exists() else 0
    local_max = _scan_dir_max_prefix(reasoning_dir)
    vault_max = _scan_dir_max_prefix(vault_reasoning_dir)
    highest = max(state_max, local_max, vault_max)
    return f"{highest + 1:03d}"


def get_next_revision(history_dir: Path) -> str:
    """Scan attachments/history/ and calculate next rev-[REV]."""
    if not history_dir.exists():
        return "001"
    highest = 0
    for entry in history_dir.iterdir():
        if entry.is_dir():
            match = RE_REV.match(entry.name)
            if match:
                highest = max(highest, int(match.group(1)))
    return f"{highest + 1:03d}"


def compute_semantic_version(rev_id: str, is_rework: bool, is_major: bool, prior_version: str = "1.0") -> str:
    """Compute semantic revision version (1.0 for new, 1.1/1.2 for minor rework, 2.0 for major)."""
    if not is_rework:
        return "1.0"
    try:
        major_num = int(prior_version.split(".")[0])
    except (ValueError, IndexError):
        major_num = 1
    if is_major:
        return f"{major_num + 1}.0"
    rev_num = int(rev_id)
    return f"{major_num}.{rev_num}"


def extract_prior_version(session_dir: Path) -> str:
    """Read prior semantic revision from README.md or plan.md if available."""
    for candidate in ["README.md", "plan.md", "000-plan.md"]:
        fp = session_dir / candidate
        if fp.exists():
            text = fp.read_text(encoding="utf-8", errors="replace")
            m = re.search(r'^revision:\s*["\']?(\d+\.\d+)["\']?', text, re.MULTILINE)
            if m:
                return m.group(1)
    return "1.0"


def parse_inline_annotations(readme_path: Path) -> list[dict[str, str | int]]:
    """Extract [[...]] inline annotations from prior README.md with section and line context."""
    if not readme_path.exists():
        return []
    text = readme_path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    annotations: list[dict[str, str | int]] = []
    current_heading = "Root"

    for idx, line in enumerate(lines, start=1):
        if line.lstrip().startswith("#"):
            current_heading = line.strip("# ").strip()
        for match in RE_ANNOTATION.finditer(line):
            annotations.append({
                "line": idx,
                "section": current_heading,
                "comment": match.group(1).strip(),
                "context": line.strip(),
            })
    return annotations


def ingest_attachments(session_dir: Path, attachment_paths: list[str] | None, utc_now: str) -> list[dict[str, str]]:
    """Copy external attachments into attachments/ and update attachments/INDEX.md."""
    attachments_dir = session_dir / "attachments"
    attachments_dir.mkdir(parents=True, exist_ok=True)
    index_file = attachments_dir / "INDEX.md"

    if not index_file.exists():
        index_file.write_text(
            "# Attachments Index\n\n"
            "| Local File | Original Source Path | Description | Ingestion Date |\n"
            "|---|---|---|---|\n",
            encoding="utf-8",
        )

    ingested: list[dict[str, str]] = []
    if not attachment_paths:
        return ingested

    existing_index = index_file.read_text(encoding="utf-8", errors="replace")
    new_rows: list[str] = []

    for raw_path in attachment_paths:
        src = Path(raw_path).expanduser().resolve()
        if not src.exists() or not src.is_file():
            sys.stderr.write(f"Warning: Attachment not found or not a file: {raw_path}\n")
            continue
        # CWE-22 safe filename: use only src.name
        safe_name = src.name
        dst = attachments_dir / safe_name
        shutil.copy2(src, dst)
        rel_local = f"attachments/{safe_name}"
        row = f"| `{rel_local}` | `{src}` | External prompt attachment | {utc_now} |"
        if rel_local not in existing_index:
            new_rows.append(row)
        ingested.append({"local_file": rel_local, "original_path": str(src)})

    if new_rows:
        with index_file.open("a", encoding="utf-8") as f:
            for r in new_rows:
                f.write(r + "\n")

    return ingested


def create_initial_documents(
    session_dir: Path,
    session_id: str,
    prompt_text: str,
    utc_now: str,
    *,
    constitution_bootstrap: bool = False,
) -> None:
    """Generate plan.md, proposal.md, design.md, task.md, and initial brief/ templates.

    Args:
        session_dir: Target directory for the reasoning session.
        session_id: Prefixed session identifier (e.g. '001_project-constitution').
        prompt_text: Verbatim trigger prompt string.
        utc_now: Formatted UTC creation timestamp.
        constitution_bootstrap: When True, marks operational_mode as constitution-bootstrap and twin READMEs optional.
    """
    title_human = session_id.split("_", 1)[-1].replace("-", " ").title()
    bootstrap_meta = (
        'operational_mode: "constitution-bootstrap"\ntwin_readme_required: false\n'
        if constitution_bootstrap
        else ""
    )

    # 1. plan.md (un-numbered)
    plan_content = f"""---
session_id: "{session_id}"
title: "{title_human}"
status: "in_progress"
revision: "1.0"
created_at: "{utc_now}"
{bootstrap_meta}languages:
  interaction: "Italian"
  final_human_deliverable: "Italian"
  ai_internal_deliverables: "English"
activator_type: "human"
enrolled_experts: []
additional_deliverables: []
tools:
  - "tokensave"
  - "read_file"
  - "write_file"
  - "ask_question"
---

# Plan: {title_human}

## Obiettivo della Sessione
*(Sintesi dell'obiettivo e del perimetro definita al termine del Workflow 03 e approvata dall'invocatore).*

## Configurazione Operativa
- **Lingua Interazione**: Italiano (Default) / English
- **Lingua Deliverable Umano (`README.md`)**: Italiano (Default) / English
- **Lingua Interna AI (`brief/`, `README.ai.md`)**: Strictly English Only
- **Deliverable Aggiuntivi Richiesti**: Nessuno *(aggiornare se richiesti dal prompt)*

## Milestone dei Workflow
- [x] **Workflow 01**: Operational Mode Selection & Automated Scaffolding
- [ ] **Workflow 02**: Silent Codebase Exploration (`tokensave`)
- [ ] **Workflow 03**: Prompt Disambiguation, Topic Breakdown & `plan.md` Approval
- [ ] **Workflow 04**: Domain Expert Enrollment & Distributed Research *(Per TOPIC)*
- [ ] **Workflow 05**: AI-to-AI Briefings (`GIVEN-WHEN-THEN`) & Consensus *(Per TOPIC)*
- [ ] **Workflow 06**: Systematic Pro/Con & Trade-Off Analysis *(Per TOPIC)*
- [ ] **Workflow 07**: Interactive Human / Activator Review *(Per TOPIC)*
- [ ] **Workflow 08**: Technical Re-Analysis & Cross-Topic Reconciliation *(Per TOPIC)*
- [ ] **Workflow 09**: Final Conscious Validation & Domain Expert Persistence Gate
- [ ] **Workflow 10**: Conditional Additional Deliverables & Twin Deliverables (`README.md` + `README.ai.md`)
- [ ] **Workflow 11**: Session Audit, Conclusion & Optional `myspec-*` Handoff
"""
    (session_dir / "plan.md").write_text(plan_content, encoding="utf-8")

    # 2. proposal.md
    proposal_content = f"""# Proposal: {session_id}

## Original Trigger Prompt
```text
{prompt_text.strip()}
```

## Disambiguated Prompt (Central Reasoning Anchor)
*(Compilato nel Workflow 03 dopo la lettura degli attachments e l'intervista di disambiguazione in `brief/00-prompt-disambiguation-qa.md`. Da quel momento costituisce l'unica fonte di verità).*

## Topic Breakdown
*(Elenco dei TOPIC atomici `TOPIC-01`, `TOPIC-02`... sottoposti al ciclo Workflows 04 -> 08).*
"""
    (session_dir / "proposal.md").write_text(proposal_content, encoding="utf-8")

    # 3. design.md
    design_content = """# Design & Architectural Decisions (Minimal)

## Glossario & Convenzioni
| Termine | Definizione Sintetica |
|---|---|

## Decisioni Architetturali (ADR Minimal)
| ID | Topic | Decisione | Razionale | Stato |
|---|---|---|---|---|

## Riferimenti Codebase (`tokensave`) & Fonti Esterne
*(Solo path relativi, simboli e riferimenti puntuali da approfondire).*
"""
    (session_dir / "design.md").write_text(design_content, encoding="utf-8")

    # 4. task.md
    task_content = f"""# Task Checklist: {session_id}

## Workflow 01: Operational Mode Selection & Scaffolding
- [x] **T01-01**: Determinazione modalità operativa (New Session vs Rework) e calcolo prefisso `[NNN]`.
- [x] **T01-02**: Esecuzione `scripts/scaffold_reasoning.py` e creazione struttura `plan.md`, `proposal.md`, `design.md`, `task.md`, `brief/`, `attachments/`.
- [ ] **T01-03**: Verifica copia allegati esterni e aggiornamento `attachments/INDEX.md`.

## Workflow 02: Silent Codebase Exploration (`tokensave`)
- [ ] **T02-01**: Verifica freschezza indice semantico (`tokensave_status`).
- [ ] **T02-02**: Esplorazione silente di moduli, simboli e pattern correlati al prompt.
- [ ] **T02-03**: Registrazione minimale dei soli riferimenti da approfondire in `design.md`.

## Workflow 03: Prompt Disambiguation, Topic Breakdown & Plan Approval
- [ ] **T03-01**: Lettura integrale preventiva di tutti i documenti in `attachments/` e link di repository.
- [ ] **T03-02**: Conferma lingue e intervista `qa` (4-6 domande, 1 per turno) registrata in `brief/00-prompt-disambiguation-qa.md`.
- [ ] **T03-03**: Scrittura del prompt espanso e disambiguato in `proposal.md`.
- [ ] **T03-04**: Scomposizione in `TOPIC-NN` in `proposal.md` ed espansione sub-checklist in `task.md` (`--init-topics`).
- [ ] **T03-05**: Aggiornamento e approvazione formale di `plan.md` da parte dell'invocatore.

## Workflow 04: Domain Expert Enrollment & Distributed Research (Per TOPIC)
- [ ] **T04-01**: Scansione `specs/agents/*.agent.md` (cache-recall) e selezione stack/domain experts + `cyber-security-expert` per ciascun TOPIC.
- [ ] **T04-02**: Ricerca web distribuita con cross-validazione su almeno 2 fonti per Hard Constraints e salvataggio in `attachments/` + `INDEX.md`.

## Workflow 05: AI-to-AI Briefings (`GIVEN-WHEN-THEN`) & Consensus (Per TOPIC)
- [ ] **T05-01**: Interviste AI-to-AI in inglese con sintassi `GIVEN-WHEN-THEN` salvate in `brief/topic-[id]-[expert]-brief.md`.
- [ ] **T05-02**: Ricerca approfondita mirata sulla codebase per il TOPIC corrente e aggiornamento `design.md`.
- [ ] **T05-03**: Domande mirate degli esperti all'invocatore (max 3 per esperto in modalità `qa`) salvate in `brief/topic-[id]-expert-activator-qa.md`.
- [ ] **T05-04**: Convergenza consenso per TOPIC (`brief/topic-[id]-consensus.md`) ed eventuale riconciliazione all'indietro (max 3 iterazioni).

## Workflow 06: Systematic Pro/Con & Trade-Off Analysis (Per TOPIC)
- [ ] **T06-01**: Analisi sistematica Pro/Con, rischi KISS/SOLID/Security e mitigazioni in `brief/tradeoffs-pro-cons.md` (prima della review).

## Workflow 07: Interactive Human / Activator Review (Per TOPIC)
- [ ] **T07-01**: Presentazione del consenso e validazione della tabella Pro/Con per TOPIC tramite `qa` (`ask_question`).
- [ ] **T07-02**: Registrazione integrale dell'intervista di review in `brief/topic-[id]-human-review.md`.

## Workflow 08: Technical Re-Analysis & Cross-Topic Sign-Off (Per TOPIC)
- [ ] **T08-01**: Ri-analisi tecnica degli esperti e verifica di non-regressione sulle decisioni dell'invocatore per il TOPIC.
- [ ] **T08-02**: Aggiornamento dei brief impattati e consolidamento finale in `brief/consensus-matrix.md`.

## Workflow 09: Final Conscious Validation & Domain Expert Persistence
- [ ] **T09-01**: Validazione conscia finale con l'invocatore sull'architettura consolidata.
- [ ] **T09-02**: Proposta esplicita via `ask_question` per l'eventuale persistenza di nuovi `domain-expert` in `specs/agents/`.

## Workflow 10: Conditional Additional Deliverables & Twin Deliverables
- [ ] **T10-01**: Co-creazione di eventuali deliverable aggiuntivi richiesti in `plan.md`.
""" + (
        """- [ ] **T10-01-CONST**: Popolazione diretta di `<spec_root>/Constitution.md` e `<spec_root>/constitution/**` e validazione `--validate-constitution`.
- [x] **T10-02**: *(Opzionale / Omesso in modalità `constitution-bootstrap`)* Generazione `README.md`.
- [x] **T10-03**: *(Opzionale / Omesso in modalità `constitution-bootstrap`)* Generazione `README.ai.md`.
"""
        if constitution_bootstrap
        else """- [ ] **T10-02**: Generazione `README.md` (Human-Oriented, tabella redattore/UTC/revisione, max 3-4 righe/paragrafo, zero meta-narrativa).
- [ ] **T10-03**: Generazione `README.ai.md` (AI-Oriented strictly English, `repository_baseline`, spec task list, progressive tree map).
"""
    ) + """
## Workflow 11: Session Conclusion & Optional MySpec Handoff
- [ ] **T11-01**: Verifica checklist di validazione finale e isolamento scritture (zero modifiche a codice sorgente).
- [ ] **T11-02**: Presentazione sommario finale con link relativi e scelta handoff verso `myspec-tdd-spec-reasoning`.
"""
    (session_dir / "task.md").write_text(task_content, encoding="utf-8")

    # 5. Initial brief/ files (Rule 3.4: all interviews and matrices live in brief/)
    brief_dir = session_dir / "brief"
    brief_dir.mkdir(parents=True, exist_ok=True)

    (brief_dir / "00-prompt-disambiguation-qa.md").write_text(
        f"""---
session: "{session_id}"
workflow: "03-prompt-disambiguation"
type: "activator-disambiguation-interview"
created_at: "{utc_now}"
---

# Prompt Disambiguation Interview (Workflow 03)

| # | Question | Activator Answer | Architectural Impact |
|---|---|---|---|
""",
        encoding="utf-8",
    )

    (brief_dir / "consensus-matrix.md").write_text(
        f"""---
session: "{session_id}"
type: "global-consensus-matrix"
updated_at: "{utc_now}"
status: "pending"
---

# Global Multi-Agent Consensus Matrix

| Topic ID | Participating Experts | Core Architectural Agreement (GIVEN-WHEN-THEN) | Iteration Count (Max 3) | Sign-Off |
|---|---|---|---|---|
""",
        encoding="utf-8",
    )

    (brief_dir / "tradeoffs-pro-cons.md").write_text(
        f"""---
session: "{session_id}"
type: "systematic-tradeoffs-pro-cons"
updated_at: "{utc_now}"
status: "pending"
---

# Systematic Pro/Con & Trade-Off Analysis

| Topic ID | Decision / Option | Pros | Cons / Risks (KISS, SOLID, Security) | Expert Mitigations | Review Verdict |
|---|---|---|---|---|---|
""",
        encoding="utf-8",
    )


def perform_rework_backup_and_delta(
    session_dir: Path, prompt_text: str, is_major: bool, utc_now: str
) -> tuple[str, str, list[dict[str, str | int]]]:
    """Backup prior artifacts into attachments/history/rev-[REV]/, parse [[...]], and update version."""
    prior_version = extract_prior_version(session_dir)
    annotations = parse_inline_annotations(session_dir / "README.md")

    history_dir = session_dir / "attachments" / "history"
    history_dir.mkdir(parents=True, exist_ok=True)
    rev_id = get_next_revision(history_dir)
    backup_target = history_dir / f"rev-{rev_id}"
    backup_target.mkdir(parents=True, exist_ok=True)

    root_files = [
        "plan.md",
        "000-plan.md",
        "proposal.md",
        "design.md",
        "task.md",
        "README.md",
        "README.ai.md",
        "qa-human-review.md",
    ]
    copied_files: list[Path] = []
    for item in root_files:
        src = session_dir / item
        if src.exists() and src.is_file():
            dst = backup_target / item
            shutil.copy2(src, dst)
            copied_files.append(dst)

    brief_dir = session_dir / "brief"
    if brief_dir.exists() and brief_dir.is_dir():
        backup_brief = backup_target / "brief"
        shutil.copytree(brief_dir, backup_brief, dirs_exist_ok=True)

    # Fail-closed verification
    for expected in copied_files:
        if not expected.exists():
            raise RuntimeError(f"Fail-closed backup check failed for {expected}")

    # Migrate legacy 000-plan.md -> plan.md if needed
    legacy_plan = session_dir / "000-plan.md"
    modern_plan = session_dir / "plan.md"
    if legacy_plan.exists():
        if not modern_plan.exists():
            shutil.move(str(legacy_plan), str(modern_plan))
        else:
            legacy_plan.unlink()

    # Migrate legacy root qa-human-review.md into brief/ if present
    legacy_qa = session_dir / "qa-human-review.md"
    if legacy_qa.exists():
        brief_dir.mkdir(parents=True, exist_ok=True)
        target_qa = brief_dir / "legacy-qa-human-review.md"
        if not target_qa.exists():
            shutil.move(str(legacy_qa), str(target_qa))
        else:
            legacy_qa.unlink()

    new_version = compute_semantic_version(rev_id, is_rework=True, is_major=is_major, prior_version=prior_version)

    # Update revision in plan.md
    if modern_plan.exists():
        plan_text = modern_plan.read_text(encoding="utf-8", errors="replace")
        if re.search(r"^revision:\s*.*$", plan_text, re.MULTILINE):
            plan_text = re.sub(
                r"^revision:\s*.*$", f'revision: "{new_version}"', plan_text, flags=re.MULTILINE
            )
        else:
            plan_text = plan_text.replace(
                'status: "in_progress"', f'status: "in_progress"\nrevision: "{new_version}"'
            )
        modern_plan.write_text(plan_text, encoding="utf-8")

    # Append rework log & parsed [[...]] annotations to proposal.md
    proposal_file = session_dir / "proposal.md"
    ann_lines = []
    if annotations:
        for a in annotations:
            ann_lines.append(f"- **Line {a['line']} ({a['section']})**: `{a['comment']}`")
    else:
        ann_lines.append("- *(No inline `[[...]]` annotations detected in prior `README.md`)*")
    ann_block = "\n".join(ann_lines)

    rework_section = f"""

---

## Rework Revision {new_version} (Backup: `attachments/history/rev-{rev_id}/` — {utc_now})

### Rework Trigger Prompt
```text
{prompt_text.strip()}
```

### Parsed Inline Annotations (`[[...]]`) from Prior `README.md`
{ann_block}

### Formal Delta Analysis
- **Confirmed**: *(Da compilare nel Workflow 01/03)*
- **Revised / Contradicted**: *(Da compilare nel Workflow 01/03)*
- **New Additions**: *(Da compilare nel Workflow 01/03)*
"""
    if proposal_file.exists():
        with proposal_file.open("a", encoding="utf-8") as f:
            f.write(rework_section)
    else:
        proposal_file.write_text(f"# Proposal: {session_dir.name}\n" + rework_section, encoding="utf-8")

    return rev_id, new_version, annotations


def initialize_topics(session_dir: Path, raw_topics: list[str], utc_now: str) -> list[dict[str, str]]:
    """Expand task.md and create per-topic files in brief/ for each topic specification."""
    brief_dir = session_dir / "brief"
    brief_dir.mkdir(parents=True, exist_ok=True)
    session_id = session_dir.name
    created_topics: list[dict[str, str]] = []

    for idx, item in enumerate(raw_topics, start=1):
        if ":" in item:
            raw_id, title = item.split(":", 1)
            raw_id = raw_id.strip().upper()
            title = title.strip()
        else:
            raw_id = f"TOPIC-{idx:02d}"
            title = item.strip()

        m = re.search(r"(\d+)", raw_id)
        num_str = f"{int(m.group(1)):02d}" if m else f"{idx:02d}"
        topic_id = f"TOPIC-{num_str}"
        file_prefix = f"topic-{num_str}"

        qa_path = brief_dir / f"{file_prefix}-expert-activator-qa.md"
        if not qa_path.exists():
            qa_path.write_text(
                f"""---
session: "{session_id}"
topic_id: "{topic_id}"
topic_title: "{title}"
workflow: "05-ai-briefings-consensus"
type: "expert-to-activator-qa"
created_at: "{utc_now}"
---

# {topic_id} ({title}) — Domain Expert QA to Activator (Max 3 Questions / Expert)

| Expert | Q# | Question | Activator Answer | Resulting Invariant (GIVEN-WHEN-THEN) |
|---|---|---|---|---|
""",
                encoding="utf-8",
            )

        cons_path = brief_dir / f"{file_prefix}-consensus.md"
        if not cons_path.exists():
            cons_path.write_text(
                f"""---
session: "{session_id}"
topic_id: "{topic_id}"
topic_title: "{title}"
workflow: "05-ai-briefings-consensus"
type: "topic-consensus"
created_at: "{utc_now}"
iterations: 1
status: "in_progress"
---

# {topic_id} ({title}) — AI-to-AI Consensus Convergence

## Participating Experts & Briefs
- *(Link topic-[id]-[expert]-brief.md files here)*

## Consolidated Topic Specifications (GIVEN-WHEN-THEN)
```gherkin
Feature: {title}
```

## Cross-Topic Impact & Backward Reconciliation Check
- **Impacts Earlier Topics?**: No
- **Reconciliation Notes**: None
""",
                encoding="utf-8",
            )

        rev_path = brief_dir / f"{file_prefix}-human-review.md"
        if not rev_path.exists():
            rev_path.write_text(
                f"""---
session: "{session_id}"
topic_id: "{topic_id}"
topic_title: "{title}"
workflow: "07-human-review"
type: "topic-human-review"
created_at: "{utc_now}"
status: "pending"
---

# {topic_id} ({title}) — Interactive Activator Review & Trade-Off Validation

| # | Question / Trade-Off Presented | Selected Option & Rationale | Requires Expert Re-Analysis (Wf 08)? |
|---|---|---|---|
""",
                encoding="utf-8",
            )

        created_topics.append({"topic_id": topic_id, "title": title, "file_prefix": file_prefix})

    # Append per-topic sub-checklist to task.md if not already present
    task_file = session_dir / "task.md"
    if task_file.exists() and created_topics:
        task_text = task_file.read_text(encoding="utf-8", errors="replace")
        sub_lines = ["\n## Per-TOPIC Execution Sub-Checklist (Workflows 04 → 08)\n"]
        for t in created_topics:
            tid = t["topic_id"]
            ttitle = t["title"]
            if f"**{tid}**" not in task_text:
                sub_lines.append(f"### {tid}: {ttitle}")
                sub_lines.append(f"- [ ] **{tid}-WF04**: Enrollment esperti e ricerca web (2-source validation)")
                sub_lines.append(f"- [ ] **{tid}-WF05**: Briefings AI-to-AI (`GIVEN-WHEN-THEN`), QA (max 3/esperto) e consenso")
                sub_lines.append(f"- [ ] **{tid}-WF06**: Analisi Pro/Con e mitigazioni in `brief/tradeoffs-pro-cons.md`")
                sub_lines.append(f"- [ ] **{tid}-WF07**: Review interattiva in `brief/{t['file_prefix']}-human-review.md`")
                sub_lines.append(f"- [ ] **{tid}-WF08**: Ri-analisi tecnica post-review, sign-off in `brief/consensus-matrix.md` e `compact`\n")
        if len(sub_lines) > 1:
            with task_file.open("a", encoding="utf-8") as f:
                f.write("\n".join(sub_lines))

    return created_topics


def consolidate_new_major(session_dir: Path, utc_now: str) -> tuple[str, str, int]:
    """Execute major version consolidation for a guided-reasoning-flow session.

    Snapshots all current session documents into <session_dir>/superseded/<version>/,
    recursively renames all markdown files within the snapshot to .md.old, excludes
    any preexisting superseded directories from being copied, and increments the
    semantic revision in plan.md to the next major version (e.g. 1.3 -> 2.0).

    Args:
        session_dir: Validated directory path of the reasoning session.
        utc_now: Formatted UTC timestamp string for logging.

    Returns:
        tuple containing (superseded_version, new_major_version, renamed_files_count).
    """
    resolved_dir = session_dir.resolve()
    prior_version = extract_prior_version(resolved_dir)

    superseded_root = (resolved_dir / "superseded").resolve()
    if not str(superseded_root).startswith(str(resolved_dir)):
        raise ValueError(f"Security: Target path escapes session boundary: {superseded_root}")
    superseded_root.mkdir(parents=True, exist_ok=True)
    superseded_target = (superseded_root / prior_version).resolve()
    if not str(superseded_target).startswith(str(superseded_root)):
        raise ValueError(f"Security: Target path escapes superseded boundary: {superseded_target}")
    superseded_target.mkdir(parents=True, exist_ok=True)

    # Copy all session entries except the superseded root directory
    for entry in resolved_dir.iterdir():
        if entry.name == "superseded":
            continue
        dest_entry = superseded_target / entry.name
        if entry.is_file():
            shutil.copy2(entry, dest_entry)
        elif entry.is_dir():
            shutil.copytree(entry, dest_entry, dirs_exist_ok=True, ignore=shutil.ignore_patterns("superseded"))

    # Recursively rename all .md files in the snapshot to .md.old
    renamed_count = 0
    for root_path, _dirs, files in os.walk(superseded_target):
        for f in files:
            if f.endswith(".md"):
                full_path = Path(root_path) / f
                new_path = Path(root_path) / (f + ".old")
                full_path.rename(new_path)
                renamed_count += 1

    # Bump version: e.g. 1.3 -> 2.0, 2.4 -> 3.0
    try:
        major_num = int(prior_version.split(".")[0])
    except (ValueError, IndexError):
        major_num = 1
    new_version = f"{major_num + 1}.0"

    # Update revision in plan.md
    plan_file = resolved_dir / "plan.md"
    if plan_file.exists():
        plan_text = plan_file.read_text(encoding="utf-8", errors="replace")
        if re.search(r"^revision:\s*.*$", plan_text, re.MULTILINE):
            plan_text = re.sub(
                r"^revision:\s*.*$", f'revision: "{new_version}"', plan_text, flags=re.MULTILINE
            )
        else:
            plan_text = plan_text.replace(
                'status: "in_progress"', f'status: "in_progress"\nrevision: "{new_version}"'
            )
        plan_file.write_text(plan_text, encoding="utf-8")

    return prior_version, new_version, renamed_count


def _is_constitution_bootstrap_session(session_dir: Path) -> bool:
    """Determine whether plan.md activates constitution-bootstrap mode.

    Args:
        session_dir: Path to the reasoning session directory.

    Returns:
        True when plan.md frontmatter sets operational_mode to constitution-bootstrap.
    """
    plan_file = session_dir / "plan.md"
    if not plan_file.is_file():
        return False
    text = plan_file.read_text(encoding="utf-8", errors="replace")
    return bool(
        re.search(
            r'^operational_mode:\s*["\']?constitution-bootstrap["\']?\s*$',
            text,
            re.MULTILINE,
        )
    )


def _infer_repo_root_from_session(session_dir: Path, explicit_repo_root: Path | None = None) -> Path:
    """Resolve the repository root containing <spec_root>/ from a session path.

    Args:
        session_dir: Reasoning session path (typically <repo_root>/reasoning/<session_id>).
        explicit_repo_root: Optional explicit repository root passed via --base-dir.

    Returns:
        Canonical resolved Path to the target repository root.
    """
    if explicit_repo_root is not None:
        return explicit_repo_root.resolve()
    resolved = session_dir.resolve()
    if resolved.parent.name == "reasoning":
        return resolved.parent.parent
    return resolved.parent


def _validate_bootstrap_constitution(repo_root: Path) -> list[str]:
    """Verify <spec_root>/Constitution.md and <spec_root>/constitution/** exist and pass Bare-Bones validation.

    Args:
        repo_root: Canonical repository root containing .myspec.config.json or openspec/specs.

    Returns:
        List of constitutional validation errors (empty when valid).
    """
    resolved_root = repo_root.resolve()
    validator_script = (
        Path(__file__).resolve().parents[2] / "myspec-validate" / "scripts" / "myspec_validate.py"
    )
    if validator_script.is_file():
        skills_init = Path(__file__).resolve().parents[2] / "myspec-init" / "scripts"
        for p_dir in (str(skills_init), str(validator_script.parent)):
            if p_dir not in sys.path:
                sys.path.insert(0, p_dir)
        try:
            from myspec_validate import MySpecValidator  # type: ignore

            validator = MySpecValidator(repo_root=resolved_root)
            if hasattr(validator, "_validate_constitution_tree"):
                errs, _warns = validator._validate_constitution_tree(require_exists=True)
                return list(errs)
        except Exception:
            pass

    # Deterministic fallback check on <spec_root>/Constitution.md and <spec_root>/constitution/**
    spec_root = "openspec"
    cfg_file = resolved_root / ".myspec.config.json"
    if cfg_file.is_file():
        try:
            cfg_data = json.loads(cfg_file.read_text(encoding="utf-8"))
            if cfg_data.get("spec_root") in {"openspec", "specs"}:
                spec_root = cfg_data["spec_root"]
        except Exception:
            pass
    elif (resolved_root / "specs" / "Constitution.md").is_file():
        spec_root = "specs"

    const_file = resolved_root / spec_root / "Constitution.md"
    const_dir = resolved_root / spec_root / "constitution"
    errors: list[str] = []
    if not const_file.is_file() or const_file.is_symlink():
        errors.append(f"Missing required populated Constitution file: {spec_root}/Constitution.md")
        return errors
    if not const_dir.is_dir() or const_dir.is_symlink():
        errors.append(f"Missing required Constitution directory: {spec_root}/constitution/")
        return errors

    root_text = const_file.read_text(encoding="utf-8", errors="replace")
    if len(root_text.splitlines()) > 45:
        errors.append(f"{spec_root}/Constitution.md exceeds 45-line Bare-Bones cap")
    if "{{" in root_text and "}}" in root_text:
        errors.append(f"{spec_root}/Constitution.md contains unresolved template placeholders")
    return errors


def validate_session(session_dir: Path, repo_root: Path | None = None) -> tuple[bool, list[str]]:
    """Validate completeness and integrity of a guided-reasoning-flow session folder.

    Args:
        session_dir: Path to the reasoning session folder.
        repo_root: Optional repository root override for constitution-bootstrap verification.

    Returns:
        tuple containing (is_valid, list_of_errors).
    """
    errors: list[str] = []
    if not session_dir.is_dir():
        return False, [f"Session directory does not exist: {session_dir}"]

    is_bootstrap = _is_constitution_bootstrap_session(session_dir)
    required_files = ["plan.md", "proposal.md", "design.md", "task.md"]
    if not is_bootstrap:
        required_files.extend(["README.md", "README.ai.md"])
    for fname in required_files:
        if not (session_dir / fname).is_file():
            errors.append(f"Missing required file: {fname}")

    # Check brief directory
    brief_dir = session_dir / "brief"
    if not brief_dir.is_dir():
        errors.append("Missing required directory: brief/")
    else:
        for bname in ["consensus-matrix.md", "tradeoffs-pro-cons.md"]:
            if not (brief_dir / bname).is_file():
                errors.append(f"Missing required brief: brief/{bname}")

    # Check task.md for unchecked tasks
    task_file = session_dir / "task.md"
    if task_file.is_file():
        content = task_file.read_text(encoding="utf-8", errors="replace")
        unchecked = re.findall(r"^[ \t]*-\s*\[ \]\s*([^\n]+)", content, re.MULTILINE)
        if unchecked:
            errors.append(f"Found {len(unchecked)} incomplete task(s) in task.md: " + "; ".join(unchecked[:5]))

    if is_bootstrap:
        inferred_repo = _infer_repo_root_from_session(session_dir, repo_root)
        errors.extend(_validate_bootstrap_constitution(inferred_repo))

    return len(errors) == 0, errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Scaffold and manage guided-reasoning-flow sessions.")
    parser.add_argument("--slug", help="Semantic slug for a new reasoning session.")
    parser.add_argument("--prompt", help="Trigger prompt string.")
    parser.add_argument("--prompt-file", help="Path to external file containing the trigger prompt.")
    parser.add_argument(
        "--attachment",
        action="append",
        default=[],
        help="External file path to copy into attachments/ and index in attachments/INDEX.md (repeatable).",
    )
    parser.add_argument("--rework-from", help="Existing session path to rework (enables Mode B).")
    parser.add_argument("--major", action="store_true", help="Increment major version (e.g. 2.0) in rework mode.")
    parser.add_argument(
        "--new-major",
        action="store_true",
        help="Execute major version consolidation, snapshotting current session to superseded/<version>/ and renaming to .md.old.",
    )
    parser.add_argument("--session-dir", help="Existing session path for --init-topics or attachment ingestion.")
    parser.add_argument(
        "--init-topics",
        action="append",
        default=[],
        help="Topic specification 'TOPIC-01:Title' to scaffold per-topic checklists and brief files (repeatable).",
    )
    parser.add_argument(
        "--constitution-bootstrap",
        action="store_true",
        help="Initialize session in constitution-bootstrap mode (twin READMEs optional; requires valid <spec_root>/Constitution.md).",
    )
    parser.add_argument("--validate", action="store_true", help="Validate session completeness and task completion.")
    parser.add_argument("--base-dir", help="Base repository root (defaults to cwd).")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format.")

    args = parser.parse_args()

    if args.validate:
        if not args.session_dir:
            print("Error: --validate requires --session-dir <dir>", file=sys.stderr)
            return 1
        sdir = Path(args.session_dir).resolve()
        explicit_base = Path(args.base_dir).resolve() if args.base_dir else None
        is_valid, errs = validate_session(sdir, repo_root=explicit_base)
        if is_valid:
            if args.json:
                print(json.dumps({"status": "PASS", "session_dir": str(sdir)}))
            else:
                print(f"PASS: Session validation passed successfully for {sdir.name}")
            return 0
        else:
            if args.json:
                print(json.dumps({"status": "FAIL", "session_dir": str(sdir), "errors": errs}))
            else:
                print(f"FAIL: Session validation failed for {sdir.name}:", file=sys.stderr)
                for e in errs:
                    print(f"  - {e}", file=sys.stderr)
            return 1

    utc_now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    if args.new_major:
        target_dir = args.session_dir or args.rework_from
        if not target_dir:
            sys.stderr.write("Error: --new-major requires --session-dir <dir> or --rework-from <dir>\n")
            return 1
        sdir = Path(target_dir).expanduser().resolve()
        if not sdir.exists() or not sdir.is_dir():
            sys.stderr.write(f"Error: Session directory does not exist: {target_dir}\n")
            return 1

        superseded_ver, new_ver, renamed_count = consolidate_new_major(sdir, utc_now)
        result = {
            "status": "success",
            "mode": "new_major_consolidation",
            "session_id": sdir.name,
            "session_dir": str(sdir),
            "relative_dir": f"reasoning/{sdir.name}",
            "superseded_version": superseded_ver,
            "superseded_dir": f"superseded/{superseded_ver}",
            "renamed_old_files_count": renamed_count,
            "semantic_version": new_ver,
            "timestamp_utc": utc_now,
        }
        if args.json:
            print(json.dumps(result, indent=2, ensure_ascii=False))
        else:
            print(f"Reasoning session major consolidation completed:")
            print(f"  Session ID:         {sdir.name}")
            print(f"  Path:               {sdir}")
            print(f"  Superseded Version: {superseded_ver}")
            print(f"  New Major Version:  {new_ver}")
            print(f"  Renamed Files:      {renamed_count} (.md -> .md.old)")
        return 0

    base_dir = resolve_base_directory(args.base_dir)
    reasoning_root = base_dir / "reasoning"
    reasoning_root.mkdir(parents=True, exist_ok=True)
    utc_now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # Read prompt text
    prompt_text = ""
    if args.prompt:
        prompt_text = args.prompt
    elif args.prompt_file:
        pf = Path(args.prompt_file).expanduser().resolve()
        if pf.exists():
            prompt_text = pf.read_text(encoding="utf-8", errors="replace")
        else:
            sys.stderr.write(f"Error: Prompt file not found: {args.prompt_file}\n")
            return 1
    else:
        prompt_text = "Prompt in attesa di specificazione."

    annotations: list[dict[str, str | int]] = []
    rev_id = "001"
    semantic_version = "1.0"

    if args.session_dir and not args.rework_from:
        session_dir = Path(args.session_dir).expanduser().resolve()
        if not session_dir.exists():
            sys.stderr.write(f"Error: Session directory does not exist: {args.session_dir}\n")
            return 1
        session_id = session_dir.name
        mode = "update_session"
        semantic_version = extract_prior_version(session_dir)
    elif args.rework_from:
        session_dir = Path(args.rework_from).expanduser().resolve()
        if not session_dir.exists():
            sys.stderr.write(f"Error: Target rework session does not exist: {args.rework_from}\n")
            return 1
        session_id = session_dir.name
        rev_id, semantic_version, annotations = perform_rework_backup_and_delta(
            session_dir, prompt_text, args.major, utc_now
        )
        mode = "rework"
    else:
        if not args.slug:
            sys.stderr.write("Error: --slug is required when creating a new session.\n")
            return 1
        safe_slug = sanitize_slug(args.slug)
        vault_env = os.environ.get("OBSIDIAN_VAULT_PATH")
        vault_rdir = (
            Path(vault_env).expanduser() / "50-Projects" / base_dir.name / "reasoning"
            if vault_env
            else None
        )
        try:
            prefix = compute_next_prefix(reasoning_root, vault_rdir)
        except ValueError as err:
            sys.stderr.write(f"Error: {err}\n")
            return 1
        session_id = f"{prefix}_{safe_slug}"
        session_dir = reasoning_root / session_id
        session_dir.mkdir(parents=True, exist_ok=True)
        (session_dir / "brief").mkdir(exist_ok=True)
        (session_dir / "attachments").mkdir(exist_ok=True)
        create_initial_documents(
            session_dir,
            session_id,
            prompt_text,
            utc_now,
            constitution_bootstrap=args.constitution_bootstrap,
        )
        mode = "constitution-bootstrap" if args.constitution_bootstrap else "new_session"

    # Ingest any attachments (plus prompt-file if external)
    attachments_to_ingest = list(args.attachment)
    if args.prompt_file:
        pf_resolved = Path(args.prompt_file).expanduser().resolve()
        if not str(pf_resolved).startswith(str(base_dir)) and str(pf_resolved) not in attachments_to_ingest:
            attachments_to_ingest.append(str(pf_resolved))

    ingested = ingest_attachments(session_dir, attachments_to_ingest, utc_now)
    created_topics = initialize_topics(session_dir, args.init_topics, utc_now) if args.init_topics else []

    result = {
        "status": "success",
        "mode": mode,
        "session_id": session_id,
        "session_dir": str(session_dir),
        "relative_dir": f"reasoning/{session_id}",
        "backup_revision": rev_id,
        "semantic_version": semantic_version,
        "parsed_annotations_count": len(annotations),
        "parsed_annotations": annotations,
        "ingested_attachments": ingested,
        "initialized_topics": created_topics,
        "timestamp_utc": utc_now,
    }

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"Reasoning session operation completed ({mode}):")
        print(f"  Session ID:       {session_id}")
        print(f"  Path:             {session_dir}")
        print(f"  Semantic Version: {semantic_version}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
