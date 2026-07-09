# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Ansible role that deploys **Apache CloudStack** management nodes and KVM hypervisors on Ubuntu (tested 24.04 LTS). This is a **fork of [bradh352/ansible-role-service-cloudstack](https://github.com/bradh352/ansible-role-service-cloudstack)** (MIT) — the `upstream/main` remote tracks it. Keep changes rebase-friendly and periodically re-sync from upstream.

## Place in the wider system

Consumed by `ansible-playbooks-cloudstack` (the orchestrator) alongside `denv-r1/ansible/*` sibling roles: `base_linux`/devsec hardening, `network_vxlanevpn`, `service_ceph`, `service_mariadb` (galera), `service_keepalived`, `service_certbot`. It assumes those ran first (DB cluster, VIPs, TLS certs, Ceph NFS export all pre-exist). Downstream, the CloudStack it stands up is what `terraform-cloudstack-poc` targets and what `cloudstack-ui-multibranding` re-skins.

## Architecture

`tasks/main.yml` sets up the APT repo (`cloudstack.sources.j2`, GPG key via `Signed-By:`), then branches by inventory group:
- Host in `cloudstack_mgmt` → `cloudstack-mgmt.yml` → `cloudstack-api.yml` (CloudMonkey `cmk` bootstrap; one mgmt node auto-elected) → `cloudstack-ldapsync.yml` (only if `cloudstack_saml_enable`).
- Host in `cloudstack_kvm` → `cloudstack-agent.yml`.

Hardcoded by design: DB names `cloud` / `cloud_usage`. SAML/LDAP user+project+network sync is driven by `files/cloudstack-ldapsync.py` (config templated to `/etc/cloudstack/ldapsync.conf`, mode 0600). Full variable reference lives in `README.md`; all credentials (`mariadb_root_password`, `cloudstack_db_password`, `*_key`, DNS API keys) are expected from an Ansible vault.

## State (assessed 2026-07-09, deep line-by-line audit)

- **Up to date:** ✅ HEAD 2026-05-04, aligned with `upstream/main`. `cloudstack_version` is a var = the APT component (e.g. `4.22`), so it auto-tracks the latest patch of that LTS branch (4.22.1.0 as of 2026-07). README examples mention 4.20 — ignore, trust the inventory value.
- **Security:** 🟢 Good (revised up after full read). TLS 1.2/1.3-only vhosts with 80→443 redirect and strong cipher suite; `no_log` on every credential task; `--encrypt-type=file` for DB/mgmt secrets; DB created `utf8mb4`/`utf8mb4_unicode_ci`; scoped MySQL grants; SAML hardened (`saml2.check.signature=true`, `SHA256`). `password:"!"` = locked account. Only real nits: `apt-key add` deprecated **and redundant** (`.sources` already has `Signed-By:`) — safe to drop; `get_url` of release key has no `checksum:` (mitigated by TLS+Signed-By). `proxy_ssl_verify off` applies **only** to the internal proxy→SSVM hop (self-signed cert) — this is the documented CloudStack pattern, not a defect.
- **Best practices:** 🟢 Good. Multi-node bootstrap-node election is idempotent; FQCN modules throughout; `changed_when`/`creates` guards on shell tasks; exhaustive CloudStack config (DRS, `io_uring`, IPv6, expunge purge). Heavy `shell`/`cmk` use is unavoidable (no CloudStack Ansible module). No `meta/main.yml` — fine for an internal fork.

### ✅ SystemVM template — correction (2026-07-09, verified against `apache/cloudstack-documentation`)

Earlier audit flagged the disabled `tasks/cloudstack-systemvm.yml` (commented out in `main.yml`) as a version-upgrade gap. **This was wrong** — verified against the official upgrade docs (`upgrading/index.rst`, `upgrading/upgrade/_sysvm_templates.rst`): since 4.16, `cloudstack-management` bundles the SystemVM templates and **auto-registers them** on secondary-storage add / management-server startup if not already present. The role's own comment ("SystemVM is supposedly bundled with the official packages these days so no need to download and install") is correct and matches upstream behavior — disabling the manual task is the *right* call, not a TODO left unfinished. No fix needed here. DB schema migrations (Flyway) also still run automatically on package restart, confirmed.

### ✅ Zone/Pod/Cluster/Host provisioning (closed 2026-07-09)

The role's README used to say, under "Variables for Configuring Cloudstack": **"Not implemented yet"** for `cloudstack_zones`/pods/clusters — closed by adding `tasks/cloudstack-zone*.yml` (zone → physical network/traffic types/VLAN IP range → pod → cluster → primary storage, mgmt-side, `run_once`) and `tasks/cloudstack-zone-host.yml` (per-KVM-host `addHost` + zone secondary storage, gated on `cloudstack_zone`/`cloudstack_pod`/`cloudstack_cluster`). All idempotent via the new `tasks/cloudstack-cmk-ensure.yml` helper (generalizes the list-then-create shape already used by `cloudstack-set-config.yml`).

Two schema extensions beyond the literal README bullet list, both required for the zone to be immediately usable rather than just created: `networks[].start_ip`/`end_ip` (public VLAN IP range + VirtualRouter enablement — skipped if absent) and per-zone `primary_storage`/`secondary_storage` (`{name, nfs_path}`, NFS-backed, mirrors the existing `cloudstack_ceph_fs` pattern — skipped if absent). Host registration uses `username=cloudstack` (no password) — reuses the SSH-key trust + sudoers NOPASSWD already set up for the `cloudstack` user in `cloudstack-agent.yml`, per `LibvirtServerDiscoverer.java`'s non-root+sudo addHost path. Primary storage hardcodes `scope=cluster` (ponytail: add `scope=zone` if a real shared-storage need shows up). Prepared as an upstream MR to `bradh352/ansible-role-service-cloudstack`. See [[cloudstack-upgrade-readiness]].

### Minor nits (unchanged)
`apt-key add` is deprecated and redundant (the `.sources` template already has `Signed-By:`) — official docs now use `wget ... | sudo tee /etc/apt/trusted.gpg.d/cloudstack.asc` with no `apt-key` step at all. `get_url` of the release key has no `checksum:` (mitigated by TLS + Signed-By). NTP/chrony setup is listed as an install prerequisite in official docs but isn't handled by any task in this role — presumably left to `base_linux`/`devsec.hardening` (not in this workspace, unverified).

## Working here

No standalone entrypoint — this role runs via `ansible-playbooks-cloudstack/bootstrap.yml`. To iterate, use `ansible-lint` and `--check`/`--diff` against a staging inventory. Preserve upstream file structure and MIT/Apache license headers to keep re-syncs clean.
