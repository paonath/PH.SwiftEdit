# Guida Operativa Skill `my-git-flow`

## Panoramica
La skill `my-git-flow` orchestra i 6 cicli di vita GitFlow mantenendo un'unica skill atomica in Antigravity (`/my-git-flow`) e 6 command shim dedicati in Claude Code (`/my-git-flow:feature-start`, `feature-finish`, `release-start`, `release-finish`, `hotfix-start`, `hotfix-finish`).
L'attivazione è esclusivamente manuale (**Human-Only Trigger**, `disable-model-invocation: true`): nessun modello AI può invocare comandi mutanti in autonomia.

## Invarianti Fondamentali SemVer 2.0.0 e GitFlow
- **Monotonicità Assoluta (`compare_semver >= 0`, `exit 2`)**: La versione è SEMPRE in aumento. Nessun comando né risoluzione di merge può mai riportare indietro una versione incrementata manualmente (anche da sviluppatori esterni che operano senza la skill).
- **Cambio versione additivo in qualsiasi momento (`--set-version "<ver>"`)**: su tutti e 6 i comandi (`--version` resta lo slug del branch). Limiti: `start-*` > padre; `finish-feature` >= branch e > `develop`; `finish-release/hotfix` pulita e > `main`/`master` (collisione tag verificata sulla versione forzata). `{height}` NBGV non viene mai sovrascritto.
- **`README.md` del ciclo di vita = SOLA versione corrente**: una sola riga `- CurrentVersion: <ver>` aggiornata in-place (riallineata a ogni comando e alla propagazione hotfix). `StartParentVersion` si ricava da `git show <BaseCommitSHA>:<manifest>` (ancestor verificato), mai dal README.
- **Isolamento degli stack nel Build/Test gate**: `.NET` solo con `.sln`/`.slnx`/`.csproj` (un solo `.sln` alla radice, altrimenti ogni `.csproj`; più soluzioni = `exit 1`), `Python` solo con `test_*.py`/`*_test.py`, `Node` solo con script `build`/`test` reali (`CI=true`), `Shell` solo con `*.bats`. `Directory.Build.props` da solo non attiva `dotnet`.
- **Immutabilità di `{height}` in NBGV**: Il placeholder `{height}` in `version.json` non viene MAI rimosso, espanso o sostituito (inclusi pre-release come `3.2.0-alpha.{height}`).
- **Metadati Obbligatori (`NAME` e `DESCRIPTION`), Normalizzazione Automatica e `Original Name`**: Alla creazione (`Start`) di `feature`, `release` o `hotfix`, se `NAME` o `DESCRIPTION` (`--description`) mancano, l'agente deve richiederli prima di invocare la CLI (`exit 2` se assenti). Su tutti e 6 i comandi lo script Python normalizza automaticamente il nome prima della validazione (`normalize_branch_slug`: pre-guardie sicurezza `exit 2`, rimozione accenti `NFKD`, tutto minuscolo, spazi/punteggiatura convertiti in `-`), validandolo su `\A[a-z0-9][a-z0-9_.-]{0,99}\Z` e registrando in apertura `- Original Name: <nome non normalizzato>` dentro `## Description` in `<spec_root>/git/<type>/<id>/README.md`.
- **Doppio Tag Obbligatorio su `main`/`master`**: Ogni chiusura di `release` o `hotfix` elimina prima il branch di lavoro e applica sul merge commit di `main`/`master` due tag annotati: `v.{x.y.z}` (normalizzato a 3 segmenti) e `<type>/<name>` (es. `release/1.2.0`, `hotfix/login-fix`).
- **Osservabilità `[VERSION]` e `--dry-run`**: Ogni mutazione di versione emette una notifica `[VERSION] <manifest>: <old> -> <new> (<reason>)` su stdout; il flag `--dry-run` simula l'operazione senza modificare file o branch.

## I 6 Comandi e Regole di Transizione

| Comando | Claude Code Shim | Regola di Versionamento Obbligatoria |
|---|---|---|
| `start-feature <nome>` | `/my-git-flow:feature-start` | Se `develop` ha un suffisso (`-alpha4`, `-beta1`, `-rc4`), incrementa il suffisso di `+1` (`-alpha5`, `-beta2`, `-rc5`). Se `develop` è pulita (`{x}`, `{x.y}`, `{x.y.z}`), incrementa di `+1` il segmento numerico e aggiunge `-alpha1`. |
| `finish-feature [nome]` | `/my-git-flow:feature-finish` | Reverse-merge di `develop` (riconciliazione `max_semver`); se la feature ha suffisso, incrementa il suffisso di `+1` e fa commit sul branch prima del merge; se ha versione pulita (bump manuale), la lascia invariata. |
| `start-release [ver]` | `/my-git-flow:release-start` | Se `develop` ha `-rc<N>`, incrementa a `-rc<N+1>`; se ha `-alpha<N>`/`-beta<N>`, passa a `-rc1` sulla stessa base; se `develop` è pulita (`> prod`), incrementa base `+1` + `-rc1` emettendo `WARNING [CLEAN_DEVELOP_BUMPED_FOR_RC]`. |
| `finish-release [ver]` | `/my-git-flow:release-finish` | Verifica `expected_final > prod` (`exit 2` se violato), rimuove `-rc<N>`, unisce in `main`/`master`, unisce in `develop` avanzandola di `+1` (pulita se `develop <= release`, o `+1` sul suffisso se `develop > release`), elimina il branch e crea i 2 tag `v.{x.y.z}` e `release/<name>`. |
| `start-hotfix [ver]` | `/my-git-flow:hotfix-start` | Verifica assenza collisioni tag (`exit 2`), incrementa di `+1` rispetto a `main`/`master` e applica `-beta1`. |
| `finish-hotfix [ver]` | `/my-git-flow:hotfix-finish` | Verifica `expected_final > prod` (`exit 2`), rimuove `-beta<N>`, unisce in `main`/`master`, propaga opzionalmente su `release/*`, avanza `develop` di `+1`, elimina il branch e crea i 2 tag `v.{x.y.z}` e `hotfix/<name>`. |

## Tabella Codici di Uscita
- `0`: Successo (o anteprima `--dry-run`).
- `1`: Fallimento Build/Test gate o rilevamento `main`/`master`.
- `2`: Violazione monotonia SemVer (`MONOTONIC VIOLATION`), collisione tag (`v.{x.y.z}` / `<type>/<name>`), `DESCRIPTION` mancante, mismatch famiglia branch in `finish-*`, o blocco gate `start-release`.
- `3`: Configurazione `.myspec.config.json` non valida, symlink rilevato o collisione dual-path audit.
- `10`: Conflitto di merge salvato in `.tmp/my-git-flow/state.json` (`--continue` riprende dalla fase esatta: `REVERSE_MERGE_PARENT`, `MERGE_INTO_MAIN`, `PROPAGATE_RELEASE`, `MERGE_INTO_DEVELOP`; completa tag e push).
- `20`: Working tree sporco o `HEAD` staccato.
