# AGENTS.md — hello_ipfs

## Overview
Minimal IPFS test page. One static HTML file in `public/`, served locally with
Python's `http.server` or added to IPFS with the `ipfs` CLI. No build step, no
dependencies, no Docker.

## Stack
- Static HTML in `public/` (`index.html`)
- `python3 -m http.server` for local serving (stdlib, nothing to install)
- `ipfs` CLI for `add` / `name publish` (must be installed + running locally)

## Structure
```
hello_ipfs/
├── ask.sh          — task runner (serve / add / publish / cleanup)
├── hello_ipfs.svg  — logo
├── public/
│   └── index.html  — the page itself
├── LICENSE         — MIT
└── README.md
```

## Tasks (`ask.sh`)
Print-style: each task prints the command to run **on the host** — kubo is not
installed in the agent container, and the agent never runs these tasks.

| ID | Task |
|----|------|
| 1 | Install Kubo — install script + `PATH` for the host |
| 2 | Serve — prints `python3 -m http.server 8092 --directory public` |
| 3 | Add — `ipfs add -r --cid-version=1 public`, root CID saved to `.cid` |
| 4 | Pin — `ipfs pin add <cid from .cid>` |
| 5 | Key — `ipfs key gen <name> --type=ed25519` |
| 6 | Key export — `ipfs key export/import`, backup file per key |
| 7 | Publish — `ipfs name publish --key <name> /ipfs/<cid>` |
| 8 | Resolve — `ipfs name resolve /ipns/<name>` |
| 9 | Gateway config — `ipfs config` for own gateway (`PublicGateways`,
    `NoFetch`, gateway/API binds, `Ipns.RepublishPeriod`) + DNSLink TXT |
| 10 | Fallback URLs — the access list for `.cid`, to print on the page |
| 11 | Clean — removes `.cid` and `*.ipfskey` |
| 0 | Exit |

The user starts the tasks — do not run `ask.sh` from the agent.

## URLs
- Local: `http://192.168.43.2:8092/` (from the agent container; never
  `127.0.0.1`, which is the agent's own namespace)
- IPFS: `/ipfs/<cid>` — the path form, gateway-independent
- Fallback order every published page carries: own gateway DNSLink name →
  `/ipns/<name>` → `/ipfs/<cid>` → `ipfs://<cid>` → another node that pins it
  (task 10 prints it)

## Runtime files (gitignored)
`.cid` (site root CID) and `*.ipfskey` (exported keys — the key **is** the
published name; keep exports off-machine). They live in the project root, are
written by the user running `ask.sh`, and are shared with the host via the
bind mount.

## Scope
This repo is public and stays **technical only**: kubo/IPFS mechanics, config,
tasks. Domain names, seller/marketplace architecture, and any deployment plan
belong to the private repo (`gitlab/merkuro/ipfs.md`), not here.

## Conventions
- **The page stays self-contained.** Inline `<style>`, inline `<svg>`, inline
  `<script>`, favicon as a `data:` URI. Nothing may be loaded from outside the
  file — the `external requests` row the page prints is the check
  (`performance.getEntriesByType("resource")` filtered to other origins must be 0).
- The CID is the identity of the content. Editing `public/index.html` changes
  the CID — re-run task 4, then task 5 to move the published name.
- `--only-hash` on task 4 keeps the repo clean: no CID-named files are written
  into the working tree. Use a real `ipfs add -r public` only when you
  deliberately want those blocks on disk.
- No comments in code unless asked.
- Veto commits; the agent prepares and verifies only.