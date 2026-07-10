# Tests

Two tiers, matched to what's actually testable without a real multi-node
MariaDB/Galera + TLS + Ubuntu hypervisor fleet:

## 1. Lint + syntax-check (fast, no Docker)

```bash
pip install ansible-core ansible-lint ansible.utils
ansible-lint --profile min .
ansible-playbook --syntax-check -i tests/inventory/syntax-check.yml tests/site-syntax-check.yml
```

Runs `main.yml` (the whole role: mgmt, agent, api, ldapsync, systemvm, zone
provisioning) through `--syntax-check` only - never executed. Catches
YAML/Jinja errors, module-arg typos, and undefined-var references across
every task file.

`--profile min` is intentional: the role's default (`production`) profile
currently has ~120 pre-existing violations (`name[casing]`, `no-changed-when`,
`risky-shell-pipe`, line-length, and a few `jinja[invalid]` false positives on
this repo's `{% do %}` Jinja idiom) unrelated to this change. `min` passes
clean. Raising the bar is separate cleanup work.

## 2. Simulator functional test (needs Docker)

```bash
./tests/run-simulator-test.sh
```

Boots the real `apache/cloudstack-simulator:4.22.0.0` image, runs
`tests/site.yml` against it (the zone/pod/cluster/host provisioning chain,
invoked directly via `include_role` + `tasks_from`, bypassing `main.yml`'s
APT/keyring setup which needs real root/APT access), then asserts the
resulting CloudStack state via `cmk list` - zone `allocationstate=Enabled`,
host `state=Up`, primary storage `state=Up`, secondary storage registered.
This is the same sequence that caught a real ordering bug (primary storage
created before any host existed in the cluster) - see `CLAUDE.md`.

Requires the Go `cmk` CLI (downloaded automatically, pinned to v6.5.0) - not
the abandoned PyPI `cloudmonkey` package, which fails to build under
Python 3.12.

**`hypervisor=KVM` note:** it's hardcoded in 3 places
(`tasks/cloudstack-zone-cluster.yml`, `tasks/cloudstack-zone-host.yml` x2).
The simulator only accepts `hypervisor=Simulator`, so this script `sed`s
those 3 lines to `Simulator` on a scratch copy of the role before running -
it does not touch the real repo files. Templating `hypervisor` as a proper
role variable would be a real improvement, but is out of scope for this
test-only change.
`ponytail: hypervisor hardcoded to KVM in 3 files, sed-patched for simulator tests; add a cloudstack_hypervisor var if a non-KVM production target ever shows up.`

**`addHost` password/URL note:** the role's real `username=cloudstack` (no password)
and `url=http://{{ cloudstack_host_mgmt_ip }}` are correct for production KVM hosts -
CloudStack's Libvirt discoverer trusts the SSH-key auth already set up by
`cloudstack-agent.yml`, and connects to the host's real management IP. The Simulator's
own host discoverer has no such SSH path: it rejects `addHost` with "Username and
Password need to be provided" if `password` is absent, and only recognizes the magic
URL `http://sim` as a discoverable resource (any real IP fails with "Cannot find the
server resources"). This script additionally `sed`s a dummy `password=password` and
`url=http://sim` onto that one `cmk add host` call, scratch-copy only - same reasoning
as the `hypervisor` patch above, not a role change.

## What's not covered

`cloudstack-mgmt.yml`, `cloudstack-agent.yml`, `cloudstack-api.yml`, and
`cloudstack-ldapsync.yml` configure real system state (packages, sudoers,
libvirt, nginx, UFW, LDAP/SAML sync) that isn't simulator-representable and
would need a full Ubuntu + Galera + LDAP test environment to exercise
functionally. Lint + syntax-check catch structural errors in those files;
deeper coverage is out of scope here.
