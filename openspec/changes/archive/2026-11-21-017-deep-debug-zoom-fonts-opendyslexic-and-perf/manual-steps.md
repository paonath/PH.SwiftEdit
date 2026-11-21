# Passaggi manuali: 017-deep-debug-zoom-fonts-opendyslexic-and-perf

### Passaggio 1: Concedere il permesso Accessibilità all'host dell'agente
- **Cosa si fa**: Impostazioni di Sistema → Privacy e sicurezza → Accessibilità → abilita l'app che esegue l'agente (Claude / Terminale / iTerm2), poi conferma via qa.
- **Motivo**: il driver GUI AX/CGEvent dell'audit (3 esecuzioni) non può leggere né cliccare l'interfaccia senza `AXIsProcessTrusted()`.

### Passaggio 2: Confermare ogni download dei file OpenDyslexic
- **Cosa si fa**: quando l'agente lo chiede, verifica nome file, sorgente (repository ufficiale OpenDyslexic) e dimensione, quindi rispondi sì/no per ciascun file.
- **Motivo**: i binari dei font sono un nuovo asset di supply chain; i loro SHA-256 vengono fissati solo dopo il tuo consenso.

### Passaggio 3 (facoltativo): Verifica manuale con VoiceOver
- **Cosa si fa**: attiva VoiceOver (Cmd+F5), percorri tab, navigatore, Settings (Cmd+,) e pannello Properties, poi riporta eventuali etichette mancanti via qa.
- **Motivo**: la scansione automatica AX copre ruoli ed etichette, ma non l'esperienza d'ascolto reale.

### Passaggio 4: Revocare il permesso Accessibilità a fine audit
- **Cosa si fa**: al termine dell'audit di verifica finale, disabilita di nuovo l'host in Privacy e sicurezza → Accessibilità.
- **Motivo**: principio del privilegio minimo; il permesso serve solo durante l'audit.
