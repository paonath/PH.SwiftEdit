# Guida Operativa Skill `move-to-second-brain`

## Panoramica
La skill `move-to-second-brain` (`/move-to-second-brain`) e il motore CLI `move_reasoning_to_second_brain.py` spostano in modo selettivo e atomico sessioni `reasoning/[NNN]_[slug]/` o file/cartelle arbitrarie dal repository locale al Vault Obsidian **SecondBrain** (`$OBSIDIAN_VAULT_PATH`, default `~/Library/Mobile Documents/iCloud~md~obsidian/Documents`).

## Caratteristiche Principali
- **Spostamento Selettivo `reasoning/`**:
  - `--session <id_o_prefisso>` (ripetibile, es. `--session 005 --session 021_skill-blackbox-cli-ergonomics`)
  - `--status <stato>` (filtra il frontmatter YAML di `plan.md`, es. `--status completed`)
  - `--all` (sposta tutte le sessioni `reasoning/[NNN]_[slug]/` mantenendo in locale `reasoning/.second-brain-state.json`)
  - Se invocata in chat senza selettori, la skill elenca le sessioni presenti e chiede conferma tramite `AskUserQuestion`.
- **Spostamento File e Cartelle Arbitrarie (`--source`)**:
  - `--source <percorso_relativo>` (ripetibile, es. `non-categorizzato/`, `docs/`, `STRATEGIA_MODELLI_AI_ANTIGRAVITY.md`)
  - `--dest-folder <sottocartella_vault>` (default `50-Projects/<ProjectName>/notes/`)
  - Esclusione automatica di `.git`, `bin`, `obj`, `node_modules`, `__pycache__`, `.DS_Store`.
- **Copia 1:1 Verbatim con `SHA-256` (Zero Secret Scrubbing)**:
  - Ogni file viene copiato byte-per-byte e verificato tramite `SHA-256` prima della cancellazione locale.
  - Come da specifica del SecondBrain privato, non viene applicata alcuna scansione segreti, redazione o deviazione in `_quarantine/`.
  - Se la destinazione esiste con lo stesso `SHA-256`, la copia viene saltata in modo idempotente; se differisce senza `--overwrite`, l'esecuzione si arresta (`exit 1`) preservando tutti i file locali.
- **Continuità Numerazione `[NNN]` (`reasoning/.second-brain-state.json`)**:
  - Aggiornamento atomico (`os.replace`) di `last_prefix` e `sessions_moved`.
  - `scaffold_reasoning.py` legge `reasoning/.second-brain-state.json` così la sessione successiva riparte da `max + 1` anche quando `reasoning/` è vuota.
- **Hub MOC & Doppio Commit Git Scoped**:
  - Aggiorna la sezione `## 🧠 Sessioni di Ragionamento & Note Archiviate (SecondBrain)` in `50-Projects/<ProjectName>.md`.
  - Esegue commit Git circoscritti ai soli percorsi toccati sia nel Vault (`--no-vault-commit` per disattivare) sia nel repository locale (`--no-repo-commit` per disattivare).

## Esempi Rapidi CLI

```bash
# Anteprima dry-run JSON di due sessioni specifiche
python3 scripts/move_reasoning_to_second_brain.py --session 005 --session 014 --dry-run --json

# Spostamento di tutte le sessioni con status completed
python3 scripts/move_reasoning_to_second_brain.py --status completed

# Spostamento di una cartella o nota arbitraria in una sottocartella del Vault
python3 scripts/move_reasoning_to_second_brain.py --source non-categorizzato --dest-folder 50-Projects/MyAntigravity/notes
```

## Codici di Uscita
- `0`: Spostamento completato con successo (o simulazione `--dry-run`).
- `1`: Collisione `SHA-256` senza `--overwrite`, errore di verifica post-copia o errore I/O.
- `2`: Selettori mancanti/sconosciuti, path traversal (`CWE-22`), symlink (`CWE-59`) o percorso protetto senza `--force`.
