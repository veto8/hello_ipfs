#!/bin/bash
# hello_ipfs — Task Runner (manual, step by step)
# ipfs/kubo not installed in this container; run these on the host

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CID_FILE="$DIR/.cid"
PORT=8092

cid() { [ -f "$CID_FILE" ] && cat "$CID_FILE"; }

while :; do
  printf "\n  hello_ipfs - Task Runner (manual steps)\n\n"
  printf "  ┌─────┬──────────────────────────────────────────────────┐\n"
  printf "  │  ID │ Description                                      │\n"
  printf "  ├─────┼──────────────────────────────────────────────────┤\n"
  printf "  │  1  │ Install Kubo (ipfs) on HOST                       │\n"
  printf "  │  2  │ Serve - python3 http.server on port %s            │\n" "$PORT"
  printf "  │  3  │ Add - ipfs add -r public -> .cid                  │\n"
  printf "  │  4  │ Pin - ipfs pin add <cid from .cid>                │\n"
  printf "  │  5  │ Key - generate a key for ipfs name publish        │\n"
  printf "  │  6  │ Key export - back the key up to a file            │\n"
  printf "  │  7  │ Publish - ipfs name publish --key <name>          │\n"
  printf "  │  8  │ Resolve - ipfs name resolve /ipns/<name>          │\n"
  printf "  │  9  │ Gateway config - ipfs config for own gateway      │\n"
  printf "  │ 10  │ Fallback URLs - the access list from .cid         │\n"
  printf "  │ 11  │ Clean - remove runtime files                      │\n"
  printf "  │  0  │ Exit                                              │\n"
  printf "  └─────┴──────────────────────────────────────────────────┘\n\n"
  printf "  Enter Task ID: "
  read -r task || exit 0

  case "$task" in
    1)
      printf "  run on host:\n"
      printf "    curl -fsSL https://dist.ipfs.tech/kubo/install.sh | sh\n"
      printf "    export PATH=\$HOME/.ipfs/kubo:\$HOME/.ipfs/kubo/bin:\$PATH\n"
      printf "    ipfs --version\n"
      printf "    ipfs version\n\n"
      ;;
    2)
      printf "  run on host:\n"
      printf "    python3 -m http.server %s --directory %s/public\n\n" "$PORT" "$DIR"
      printf "  open http://localhost:%s/\n\n" "$PORT"
      ;;
    3)
      printf "  run on host (last line = site root, saved to .cid):\n"
      printf "    ipfs add -r --cid-version=1 %s/public | tail -1 | awk '{print \$NF}' > %s\n\n" "$DIR" "$CID_FILE"
      printf "  .cid now holds: %s\n\n" "$(cid || echo 'not set - run the command first')"
      ;;
    4)
      printf "  run on host:\n"
      printf "    ipfs pin add %s\n\n" "$(cid || echo '/ipfs/<cid - run task 3 first>')"
      ;;
    5)
      printf "  run on host (one key per site/name):\n"
      printf "    ipfs key gen <name> --type=ed25519\n"
      printf "    ipfs key list\n\n"
      ;;
    6)
      printf "  run on host (the key IS the name - keep the file off-machine):\n"
      printf "    ipfs key export <name> -o %s/<name>.ipfskey\n" "$DIR"
      printf "    ipfs key import <name> %s/<name>.ipfskey\n\n" "$DIR"
      ;;
    7)
      printf "  run on host:\n"
      printf "    ipfs name publish --key <name> /ipfs/%s\n\n" "$(cid || echo '<cid - run task 3 first>')"
      printf "  with your own gateway the record resolves locally right away;\n"
      printf "  remote gateways see it after DHT propagation.\n\n"
      ;;
    8)
      printf "  run on host:\n"
      printf "    ipfs name resolve /ipns/<name>\n\n"
      ;;
    9)
      printf "  run on host (gateway serves only what you pinned, never the network):\n"
      printf "    ipfs config --json Addresses.Gateway '[\"/ip4/0.0.0.0/tcp/8080\"]'\n"
      printf "    ipfs config --json Gateway.PublicGateways '{\"<gateway.example.com>\":{\"Paths\":[\"/ipfs\",\"/ipns\"],\"NoDNSLink\":false}}'\n"
      printf "    ipfs config --json Gateway.NoFetch true\n"
      printf "    ipfs config Ipns.RepublishPeriod 1h\n"
      printf "    ipfs config --json Addresses.API '[\"/ip4/127.0.0.1/tcp/5001\"]'\n\n"
      printf "  DNS for DNSLink (written once per name):\n"
      printf "    _dnslink.<name>  TXT  dnslink=/ipns/<name>\n\n"
      printf "  keep Host + X-Forwarded-* intact in the reverse proxy,\n"
      printf "  otherwise the PublicGateways entry never matches.\n\n"
      ;;
    10)
      C="$(cid)"
      if [ -z "$C" ]; then
        printf "  .cid is empty - run task 3 first.\n\n"
      else
        printf "  fallback access for this site (try in this order):\n\n"
        printf "    1  http://<your-gateway-domain>/ipns/<name>\n"
        printf "    2  http://<your-gateway-domain>/ipfs/%s\n" "$C"
        printf "    3  http://127.0.0.1:8080/ipfs/%s\n" "$C"
        printf "    4  ipfs://%s\n" "$C"
        printf "    5  http://<any-other-node-you-pin-on>/ipfs/%s\n\n" "$C"
        printf "  print these on the page itself so visitors can get in\n"
        printf "  even when your gateway or domain is unreachable.\n\n"
      fi
      ;;
    11)
      printf "  run on host:\n"
      printf "    rm -f %s/.cid %s/*.ipfskey\n\n" "$DIR" "$DIR"
      ;;
    0)
      printf "  Bye.\n\n"
      exit 0
      ;;
    *)
      printf "  unknown task: %s\n\n" "$task"
      ;;
  esac
  printf "  Press Enter..."
  read -r _ || exit 0
  printf "\n"
done
