# Brink features (fork: rafaelbarea/codenotch, branch `brink-features`)

Everything under `Sources/Brink/`, plus small hooks in `AppDelegate`, `StatusItemController`,
`TooltipCard`, `NotchLayout`, `SettingsView`, `ProviderGlyph` and `CodexUsage`.

## What it adds
- **Cost per project.** One SQLite database per account (Claude and Codex profiles, discovered by
  Codenotch) fed by the CLIs' transcripts; limit samples taken from Codenotch's usage snapshots;
  every rise of a limit is split across the turns that ran in that interval. Plan detected once a
  day (Claude OAuth profile tier, Codex plan type); a week of the plan costs price ÷ 4.35; a project
  that used 4% of the weekly allowance spent 4% of that. Business/Team Codex seats are credit-based:
  a Credits window from the spend control, priced per credit. API-billed accounts use OpenRouter's
  per-token prices. Exchange rate from open.er-api.com. Data in
  `~/Library/Application Support/Codenotch/brink/`; plans in `plans.json` there (editable).
- **Card section.** A usage ring's hover card lists the projects that consumed this week's (or
  cycle's) allowance and the money that is worth.
- **Activity window** (menu → Activity…, ⌘A): day / week / month, per account, lanes or bars per
  day, sessions per project with cost.
- **Tasks ring** (switch on in Settings → Accounts): today's done ÷ total from Things 3 or Reminders;
  hover card with Today / Tomorrow / one list, complete, add ("@" picks the project), open in the
  app, focus timer per task or free. While a task is in focus the ring is the timer.
- **Focus window** (menu → Focus…, ⌘F, or Settings → Focus): day / week / month, per project, editable blocks.
- **New session…** (⌘N): runs a command (default `claude`) in a new window of your terminal.
- **Settings → Costs & Tasks**: billing per account, market data, task source, focus block, launcher.
  Activity and Focus are sidebar sections of the same window.
- **Hover card size**: the card follows Appearance → Notch size (small / medium / large), capped so it
  never runs off the screen. The tasks card takes the keyboard: type a task or a free focus in place.
- **Displays**: Appearance → Displays: All displays puts one notch on every screen, each honouring the
  visibility setting (always show / on hover / hidden); switching needs no restart.
- **Shell export**: `…/brink/accounts.json` and `~/.config/brink/aliases.zsh` so a shell launcher can
  list the accounts.

## Upstream
- Ghostty tab focus by working directory: vinzdg/codenotch#226.
