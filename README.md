# os-starlink

An OPNsense plugin to monitor and control a SpaceX Starlink dish from the web UI.

> Unofficial project, not affiliated with SpaceX, Starlink or Deciso.
> **Status: beta (0.9).** It has been tested against a simulated dish.
> Reports from real dishes are very welcome.

![Status page](docs/status.png)

## Features

- **Status:** state, latency, packet loss, throughput, obstruction %, alerts, firmware,
  GPS and pointing.
- **Wake now:** wakes a sleeping dish for 1 to 24 hours, or until resumed. The previous
  sleep schedule comes back automatically afterwards.
- **Sleep schedule:** set it in your local time. The dish stores it in UTC, and the
  plugin converts it.
- **Managed schedule** (optional): OPNsense owns the sleep window and re-applies it every
  5 minutes, which corrects the daylight-saving shift.
- **Controls:** reboot, stow/unstow (dishes with motors), GPS on/off and snow melt mode.
- **Updates:** shows when the dish has a firmware update ready (Update now reboots it to install) and, on request, whether a newer plugin version is on GitHub.
- **Dish model:** detected from the dish, or chosen in Settings. Controls a model does not have are hidden.
- **History:** latency, loss, throughput and power draw for up to 12 hours, plus outages.
- **Obstruction map** and a **dashboard widget**.
- **No extra packages:** it talks to the dish's local gRPC API using only the Python that
  ships with OPNsense.

## Requirements

OPNsense must be able to reach the dish at `192.168.100.1`. With your own router (Starlink
router in bypass mode), add a virtual IP on the WAN:

1. **Interfaces → Virtual IPs → Settings → +**
2. Mode **IP Alias**, Interface **WAN**, Address **192.168.100.2/24**. Save, then Apply.

To use the Starlink phone app from your LAN as well, also add a hybrid outbound NAT rule:
WAN, source LAN net, destination `192.168.100.1/32`, translation `192.168.100.2`.

## Install

SSH into OPNsense as root (choose option **8** for a shell) and run:

```sh
fetch -o - https://horizon10t.github.io/os-starlink/setup.sh | sh
```

Then go to **System → Firmware → Plugins**, click **Check for updates**, and install
**os-starlink**. It appears under **Services → Starlink**. New versions then show up as
normal plugin updates.

The script adds `/usr/local/etc/pkg/repos/starlink.conf` and the repository's signing-key
fingerprint. See https://horizon10t.github.io/os-starlink for manual steps and removal.

## Uninstall

Remove **os-starlink** under System → Firmware → Plugins. Then, to drop the repository:

```sh
rm /usr/local/etc/pkg/repos/starlink.conf
rm -r /usr/local/etc/pkg/fingerprints/starlink
```

## Troubleshooting

```sh
configctl starlink status                         # what the UI sees
/usr/local/opnsense/scripts/starlink/dish.py status   # same, shows Python errors
ping 192.168.100.1                                # is the dish reachable?
```

If **Services → Starlink** is missing after an install or update, log out and back in and press Ctrl+F5. The installer clears the web UI caches and restarts the web server for you; if it still does not show:

```sh
rm -f /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json /var/lib/php/tmp/opnsense_menu_cache.xml /var/lib/php/tmp/opnsense_acl_cache.json
configctl webgui restart
```

When opening an issue, include the output of the first two commands, your OPNsense
version and your dish model.

---

## Maintainer guide

### Layout

```
net/starlink/            the plugin, in opnsense/plugins format (drop-in for an upstream PR)
  Makefile               version, maintainer, PLUGIN_NO_ABI (one package for every FreeBSD/arch)
  +POST_INSTALL.post     registers the cron job after install
  src/...                files installed under /usr/local
ci/check.sh              static checks and unit tests (Linux)
ci/build-freebsd.sh      builds the .pkg with the official plugins build system and signs the repo
ci/make-site.sh          builds the GitHub Pages site (repo, setup.sh, index.html)
tests/test_backend.py    unit tests for the protobuf/HTTP2/HPACK client
tools/gen_schema.py      regenerates starlink_proto.py from the Starlink .proto files
tools/make-signing-key.sh  creates the repository signing key
tools/install-manual.sh  copy-install without packages (development)
```

### One-time setup

1. **Signing key.** On your own computer, outside this repo, run:
   ```sh
   sh tools/make-signing-key.sh ~/os-starlink-signing
   ```
   Add the printed one-line value as a repository secret named **`REPO_SIGNING_KEY_B64`**
   (Settings → Secrets and variables → Actions). Back up `repo.key`. Without the secret the
   repository is published unsigned.
2. **GitHub Pages.** Settings → Pages → Source: **GitHub Actions**.
3. **Maintainer.** Set `PLUGIN_MAINTAINER` in `net/starlink/Makefile` to your email.

### Releasing

1. Bump `PLUGIN_VERSION` in `net/starlink/Makefile` and put the same number in `net/starlink/src/opnsense/scripts/starlink/VERSION` (the in-app update check reads it; CI fails if they differ), for example `1.0`, and commit.
2. Tag and push:
   ```sh
   git tag v1.0 && git push origin main v1.0
   ```
3. The **build** workflow checks the code, builds `os-starlink-1.0.pkg` in a FreeBSD VM,
   signs the repository and publishes it to GitHub Pages. Firewalls see the update on their
   next update check.

The tag must match the Makefile version. Every push to `main` builds the package as a
downloadable workflow artifact without publishing. **Run workflow** (manual dispatch)
publishes the current `main`.

### When SpaceX changes the API

```sh
pip install grpcio-tools hpack
git clone --depth 1 https://github.com/Eitol/starlink-client /tmp/sc
python3 tools/gen_schema.py /tmp/sc/proto net/starlink/src/opnsense/scripts/starlink/starlink_proto.py
python3 tests/test_backend.py
```

### Upstreaming

`net/starlink` follows the opnsense/plugins layout, so it can be submitted to
https://github.com/opnsense/plugins as a pull request once it has been tested more widely.

## Licence

BSD 2-clause, see [LICENSE](LICENSE). Third-party material is listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
