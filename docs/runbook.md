# Runbook

## Obiettivo

Questo progetto copre la personalizzazione completa dell'ambiente Windows: impostazioni, wallpaper e installazione app con winget.

## Fasi

Le fasi operative sono descritte in [docs/phases.md](docs/phases.md).

Script di avvio fasi: scripts/phases/

## Avvio rapido

1. Esegui scripts/bootstrap.ps1
2. Personalizza config/packages.json
3. Esegui scripts/install.ps1

## Wizard

- Avvio guidato: wizard.ps1

## Firma script (self-signed)

- Genera certificato e firma tutti gli script: scripts/sign.ps1
- Se il timestamp fallisce (offline), usa: scripts/sign.ps1 -NoTimestamp

## Firma script (certificato reale)

- Workflow: .github/workflows/sign-ps1.yml
- Script locale: scripts/sign-release.ps1
- Secret richiesti su GitHub:
	- CODESIGN_CERT_BASE64 (PFX in base64)
	- CODESIGN_CERT_PASSWORD

## Personalizzazione impostazioni

- Salva le impostazioni da applicare in config/settings/
- Gli script sono gia presenti in scripts/

### UI e comfort

- Tema e colori: config/settings/theme.json -> scripts/theme.ps1
- Taskbar: config/settings/taskbar.json -> scripts/taskbar.ps1
- Explorer: config/settings/explorer.json -> scripts/explorer.ps1
- Notifiche: config/settings/notifications.json -> scripts/notifications.ps1

## Wallpaper

- Inserisci i wallpaper in assets/wallpapers/
- Configura percorsi e stile in config/settings/wallpaper.json
- Usa scripts/wallpaper.ps1 per applicare wallpaper e lock screen
- La lock screen richiede PowerShell avviato come amministratore

## Installazioni con winget

- Aggiungi i pacchetti in config/packages.json (profili)
- Usa scripts/install-phase2.ps1 per la Fase 2
- Avvio rapido: scripts/phases/phase2.ps1 -Profiles base,dev
- Per installer visibili e scelta percorso, lascia default (interactive)

## Fase 3 - Sistema

- Privacy: scripts/privacy.ps1
- Power plan: scripts/power.ps1
- Windows Update: scripts/update.ps1
- Avvio rapido: scripts/phases/phase3.ps1

## Fase 4 - Produttivita

- Start Menu: config/settings/startmenu.json -> scripts/startmenu.ps1
- Snap Layouts: scripts/snap.ps1
- Windows Terminal: scripts/terminal.ps1
- Oh My Posh: scripts/ohmyposh.ps1
- Cleanup: scripts/cleanup.ps1
- Avvio rapido: scripts/phases/phase4.ps1

## Fase 5 - Backup ed export

- Config: config/settings/backup.json
- Script: scripts/backup.ps1
- Avvio rapido: scripts/phases/phase5.ps1

## Note

- Registra output in logs/ se necessario
