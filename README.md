<img src="hello_ipfs.svg" alt="hello_ipfs" width="120">

# hello_ipfs

A minimal, self-contained static page that can be served locally or published to
IPFS. No build step, no dependencies — just install Go, build/install Kubo
(the IPFS implementation), and add the page.

Tutorial: https://letsdecentralize.org/tutorials/ipfs.html

## Overview

| Path                | What it is                                          |
|---------------------|-----------------------------------------------------|
| `public/index.html` | The page itself (self-contained, no external files) |
| `install.sh`        | Installs the latest Go toolchain into `/usr/local/go` |
| `ask.sh`            | Interactive task runner (manual steps)              |
| `kubo/`             | Kubo source (gitignored, created by step 2)         |

## Requirements

- Linux with `systemd`
- `git`, `make`, `wget`, `sudo`, and `python3` (for local preview)

## 1. Install Go

Kubo is written in Go, so install the toolchain first:

```bash
sudo ./install.sh
```

This downloads the latest Go, extracts it to `/usr/local/go`, and adds
`/usr/local/go/bin` to `PATH`. Open a new shell (or `source /root/.bashrc`)
before continuing.

## 2. Install Kubo

Build Kubo from source and install the `ipfs` binary:

```bash
git clone https://github.com/ipfs/kubo; cd kubo
make build
sudo mv ./cmd/ipfs/ipfs /usr/local/bin
ipfs init
```

## 3. Create the systemd service

Create the unit file:

```bash
sudo editor /usr/lib/systemd/system/ipfs.service
```

Paste the following contents:

```ini
[Unit]
Description=IPFS
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
ExecStart=/usr/local/bin/ipfs daemon
ExecReload=/usr/local/bin/ipfs daemon
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

## 4. Register and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable ipfs
sudo systemctl start ipfs
```

Check that it is running:

```bash
systemctl status ipfs
```

## 5. Publish the site

Add the folder containing your site (here `public/`):

```bash
ipfs add -r --cid-version=1 public
```

Example output:

```
added bafkreiaz2uuo52cwwqi3z36ul4dhfefnumwhinvijaj65z5iezayy24b3y public/index.html
added bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4 public
```

The **last** CID is the site root:

```
bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4
```

### Open it

- Local gateway: http://127.0.0.1:8080/ipfs/bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4/
- Public gateway: https://bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4.ipfs.dweb.link/

Verify the contents:

```bash
ipfs ls bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4
```

## Updating the site

The CID is the identity of the content — editing `public/index.html` changes it.
Re-run step 5 to get the new CID, and republish if you use IPNS or DNSLink.

## Local preview (without IPFS)

```bash
python3 -m http.server 8092 --directory public
# then open http://localhost:8092/
```

## Pinning practice

A quick hands-on to see the availability rule (reachable ⟺ pinned):

```sh
ipfs add --cid-version=1 public/test.html   # note the bafy… CID
ipfs pin add <cid>
ipfs pin ls --type=recursive                # listed as pinned
ipfs pin verify <cid>                       # ok: no missing blocks
ipfs refs -r <cid>                          # every block the DAG needs
# serve: http://127.0.0.1:8080/ipfs/<cid>/
ipfs pin rm <cid>                           # page still loads (blocks cached)
ipfs repo gc                                # now it 404s: NoFetch gateway
ipfs pin add <cid>                          # back again
```

Why it behaves this way: the gateway runs `NoFetch true`, so it serves only
the local repo. A pin marks blocks keep-forever; unpinning + `repo gc` is
what actually removes them from the node. `public/test.html` is the
experiment subject — `public/index.html` is the real site and is left alone.

## License

GPL-3.0 — see [LICENSE](LICENSE).
