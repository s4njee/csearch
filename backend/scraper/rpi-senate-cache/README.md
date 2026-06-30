# Senate vote cache — Raspberry Pi fetcher

senate.gov blocks the netcup (production) datacenter IP, so the main pipeline
can't pull Senate roll-call votes directly. The fix is to fetch from a **US
residential IP** and drop the XML into the `senate-vote-cache` branch, which the
pipeline reads. Today a GitHub Action (`.github/workflows/senate-vote-cache.yml`)
does this. This directory runs the **same job on a home Raspberry Pi** instead.

A residential US IP is the most durable fetcher — less likely to be blocked than
either netcup or GitHub's Azure ranges.

## How it coexists with the GitHub Action

Run **both.** The publish step is diff-gated (`git diff --cached --quiet` → no-op
when nothing changed), so whichever runs first publishes and the other does
nothing. The RPi is primary; the Action is a free fallback for when the RPi is
offline. Nothing to disable.

> ⚠️ Only works if the RPi is physically in the US. A non-US residential IP may
> hit the same geoblock as netcup.

## What it does

`fetch-senate-votes.sh` mirrors the workflow exactly:

1. Clone/update the scraper code (`SCRAPER_REF`, default `main`).
2. `python run.py votes --congress=<current> --chamber=senate --download_only --force`
   (in `backend/scraper/congress/`).
3. rsync `senate.xml` + `s*.xml` into a payload.
4. Clone the `senate-vote-cache` branch, rsync the payload with `--delete`,
   commit if changed, and push.

It's pure Python over HTTP/XML — no Rust, no database — so it runs fine on
ARM / Raspberry Pi OS.

## Setup

Prereqs: `git`, `rsync`, `python3`, `python3-venv` (`sudo apt install -y git rsync python3 python3-venv`).

1. **GitHub token** — create a *fine-grained PAT* scoped to this repo with
   **Repository permissions → Contents: Read and write**. That's the only scope
   needed (it pushes one branch).

2. **Install the script:**
   ```bash
   sudo install -m 0755 fetch-senate-votes.sh /usr/local/bin/fetch-senate-votes.sh
   ```

3. **Create the env file** (holds the token — keep it out of git):
   ```bash
   sudo cp senate-vote-cache.env.example /etc/senate-vote-cache.env
   sudo nano /etc/senate-vote-cache.env      # paste the PAT
   sudo chmod 600 /etc/senate-vote-cache.env
   ```

4. **Install the systemd units:**
   ```bash
   sudo cp systemd/senate-vote-cache.service systemd/senate-vote-cache.timer /etc/systemd/system/
   # The unit runs as User=pi — edit it if your login user differs.
   sudo systemctl daemon-reload
   ```

5. **Test once, then enable the timer:**
   ```bash
   sudo systemctl start senate-vote-cache.service     # run now
   journalctl -u senate-vote-cache.service -n 50      # check it fetched + published
   sudo systemctl enable --now senate-vote-cache.timer
   systemctl list-timers senate-vote-cache.timer      # confirm next run
   ```

Verify the branch updated:
```bash
git ls-remote origin senate-vote-cache
```

## Notes

- **Schedule** matches the Action: 13:00, 17:00, 21:00 UTC (`Persistent=true`
  catches up a missed run after downtime).
- **`WORK_DIR=/var/lib/senate-vote-cache`** is created/owned by systemd
  (`StateDirectory=`). If you point `WORK_DIR` at your home directory instead,
  relax `ProtectHome=` in the service unit.
- **`FORCE=0`** in the env file switches to incremental fetching (only new votes)
  — gentler on senate.gov and faster, at the cost of CI-exact parity. The default
  `FORCE=1` re-downloads the full current Congress each run, like the Action.
- The token only ever lives in an ephemeral checkout that the script recreates
  each run; it is not persisted in any git remote between runs.
