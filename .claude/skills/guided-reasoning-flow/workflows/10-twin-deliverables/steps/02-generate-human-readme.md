# Step 02: Generate `README.md` (Human-Oriented Deliverable)

## Actions
1. Retrieve human author name (`git config user.name`), current UTC timestamp (`YYYY-MM-DD HH:MM:SS UTC`), and semantic revision from `plan.md` (`1.0`, `1.1`...).
2. Write `README.md` in the configured human deliverable language with YAML frontmatter (`author`, `creation_date`, `revision`) and the mandatory header table directly under the H1 title:
   ```markdown
   | Redattore | Data Creazione | Revisione |
   |---|---|---|
   | **[Nome Redattore]** | **YYYY-MM-DD HH:MM:SS UTC** | **[1.0]** |
   ```
3. Enforce writing rules:
   - Exhaustive yet ultra-concise; comparative tables and dense bullets.
   - Maximum **3 to 4 lines per discursive paragraph**.
   - **Zero Meta-Narrative** (never recount agent debates; state decisions and technical rationale directly).
4. Include all 5 mandatory sections:
   1. `Contesto & Obiettivo` / `Context & Objective`
   2. `Architettura & Decisioni Chiave` / `Architecture & Key Decisions`
   3. `Trade-off & Rischi Mitigati` / `Trade-offs & Mitigated Risks`
   4. `Piano di Esecuzione / Prossimi Passi` / `Execution Plan & Next Steps`
   5. `Riferimenti e Fonti Web` / `References & Web Sources`
5. Mark `T10-02` as `[x]` in `task.md`.
