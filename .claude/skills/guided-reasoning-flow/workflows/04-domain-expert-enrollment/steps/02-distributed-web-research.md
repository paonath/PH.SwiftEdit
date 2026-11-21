# Step 02: Distributed Online Research & Attachment Indexing

## Actions
1. Enrolled experts execute targeted `search_web` queries for the active `TOPIC-NN` where external documentation, standards, or version constraints are required.
2. Apply **2-Source Cross-Validation** for every Hard Constraint:
   - Cite at least two independent upstream URLs (official vendor docs, RFCs, standards).
   - Separate **Verified Facts** (with URLs) from **Domain Deductions**.
   - If two authoritative sources contradict each other, document both conflicting URLs without guessing so the conflict is escalated to the activator review.
3. If web searches were performed, save the research dossier to `attachments/web-research-topic-[id].md` and append an entry to `attachments/INDEX.md` (`| attachments/web-research-topic-[id].md | Web Search (2-source validated) | Online research for TOPIC-[id] | <UTC-date> |`).
4. Update `design.md` with minimal reference links and mark `TOPIC-[id]-WF04` as `[x]` in `task.md`.
