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
User=kubo
Group=kubo
Environment=IPFS_PATH=/var/lib/ipfs/.ipfs
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
su - kubo

ipfs add -r --cid-version=1 /var/customers/webs/ipfs      # last line = new root
ipfs pin add --recursive <new-root>                      # protect it
ipfs name publish --key self /ipfs/<new-root>            # repoint nameplate
ipfs name resolve /ipns/k51qzi5uqu5djuqjghr8zjua890ezea8a3ir07hqubkeg42za3ta3i4up8l9lc
```

Example output:

```
added bafkreibj25a6i7ky46w7lidlkfhwj44zdld35blrfnjks5earv7cajecnm ipfs/hello.html
added bafkreih72h2u4ypi5trhd5bmyqebmlqeyjd2v75lkyl7ur5tyhdecaokra ipfs/index.html
bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4
```

The **last** CID is the site root:

```
added bafybeie3lkciw7b4qauz2niir6fv4i6rdp5u5kuodchrkuitnilpp4zg5a ipfs 

```

### Open it

- Local gateway: http://127.0.0.1:8080/ipfs/bafybeicor3q2zndxy5vehl3467bhf2irghtayo42xw5gfpergic4olp4a4/
- Public gateway: https://bafybeie3lkciw7b4qauz2niir6fv4i6rdp5u5kuodchrkuitnilpp4zg5a.ipfs.inbrowser.link/

## Open via the key or your IPNS:
```
https://ipfs.io/ipns/k51qzi5uqu5djuqjghr8zjua890ezea8a3ir07hqubkeg42za3ta3i4up8l9lc
https://k51qzi5uqu5djuqjghr8zjua890ezea8a3ir07hqubkeg42za3ta3i4up8l9lc.ipns.inbrowser.link/
```
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


## Commands 
### List all keys 
```
su - kubo```
ipfs key list -l
```


### List all pins
```
su - kubo 
ipfs pin ls 
```

## Day notes — republish, pin, IPNS (2026-10-08)

- **Content address, not location.** A CID is a hash wrapper (UnixFS node); a
  folder CID is the hash of the *directory index* (`name -> child CID`), so one
  folder CID exposes the whole tree. There is no path->CID registry — you
  cannot ask "which file made this CID?". Restore content as files with
  `ipfs get /ipfs/<cid>`, or find the source by re-hashing candidates
  (`ipfs add -rqn --only-hash --cid-version=1 <dir>` and compare roots).
- **`add` != `pin`.** `ipfs add` writes *loose* blocks; only
  `ipfs pin add --recursive` protects them from `repo gc`. Old /ipfs/<cid>
  URLs stay alive while their blocks are pinned on any node; they die only
  after `pin rm` + `repo gc` on every holder.
- **The name never moves — the pointer does.** The `self` key is the identity
  (`/ipns/k51q...`), fixed for the lifetime of the keystore. Publishing moves
  only the target: `ipfs name publish --key self /ipfs/<cid>`;
  `ipfs name resolve /ipns/<key>` reads it back. Never lose the key
  (`ipfs key export`).
- **Publish can hang behind NAT** because the DHT put times out. Wait ~90 s;
  if still stuck, Ctrl-C and publish with `--allow-offline` (record stored
  locally, daemon re-publishes to the DHT on its own schedule).
- **Permanence.** A recursive pin on this node plus at least one other node
  pinning the same CID. The "URL never changes" layer is DNSLink:
  `dnslink=/ipns/<key>` TXT — the record is written once; every edit only
  moves the IPNS hop.
- **Ports.** Only the swarm port (4001/tcp) is public by default; API (5001)
  and the HTTP gateway (8080) bind localhost. Gateway with `NoFetch=true`
  serves only what the local repo holds.
- **Out-of-band check.** Same bytes anywhere -> same CID (deduplication). On
  2026-10-08 the repo's `public/index.html` did **not** match the live source
  (`/var/customers/webs/ipfs`) — keep the two mirrors byte-identical so a
  rebuild reproduces the same CID.
- **Republish log (host source `/var/customers/webs/ipfs`, key `self`):**

  | step | root CID | files |
  |------|----------|-------|
  | before | `bafybeicor3q2...olp4a4` | index.html |
  | after edit | `bafybeifs7g...egmkm` | index.html |
  | added hello.html | `bafybeie3lk...zg5a` | hello.html, index.html |
  | latest | `bafybeig7uj...gtum` | hello.html, index.html |

## License

GPL-3.0 — see [LICENSE](LICENSE).
