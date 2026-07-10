#!/usr/bin/env bash
# Functional test: boots the real apache/cloudstack-simulator image, runs the
# zone/pod/cluster/host provisioning tasks against it via tests/site.yml, then
# asserts the resulting CloudStack state is actually usable (not just "no
# Ansible error"). This is the same sequence that caught the primary-storage
# ordering bug fixed in tasks/cloudstack-zone-host.yml - see CLAUDE.md.
set -euo pipefail

ROLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
CONTAINER_NAME="cs-sim-test-$$"
SIM_IMAGE="apache/cloudstack-simulator:4.22.0.0"
CMK_VERSION="6.5.0"
CMK_BIN="${WORK_DIR}/cmk"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

echo "==> Starting ${SIM_IMAGE}"
docker run -d --name "${CONTAINER_NAME}" -p 8080:8080 "${SIM_IMAGE}" >/dev/null

echo "==> Waiting for management API on :8080 (simulator cold boot can take several minutes)"
# listApis without auth returns HTTP 401 (valid JSON error, API is up) - curl -sf would
# treat that as failure forever, so check for *any* HTTP response instead of a 2xx.
api_up() {
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080/client/api?command=listApis&response=json" 2>/dev/null)"
  [ "${code}" != "000" ]
}
for _ in $(seq 1 120); do
  if api_up; then
    break
  fi
  sleep 10
done
api_up || {
  echo "FAIL: simulator API never came up" >&2
  docker logs "${CONTAINER_NAME}" >&2 || true
  exit 1
}

echo "==> Installing cmk (Go CloudMonkey ${CMK_VERSION}, NOT the abandoned PyPI cloudmonkey package)"
curl -sfL -o "${CMK_BIN}" \
  "https://github.com/apache/cloudstack-cloudmonkey/releases/download/${CMK_VERSION}/cmk.linux.x86-64"
chmod +x "${CMK_BIN}"
export PATH="${WORK_DIR}:${PATH}"

echo "==> Bootstrapping cmk"
cmk set url http://localhost:8080/client/api
cmk set username admin
cmk set password password
cmk set domain /
cmk sync >/dev/null

echo "==> Patching hypervisor=KVM -> Simulator, adding a dummy password, and using the Simulator's magic host URL, for this run only"
TEST_ROLE_DIR="${WORK_DIR}/role"
cp -r "${ROLE_DIR}" "${TEST_ROLE_DIR}"
sed -i 's/hypervisor=KVM/hypervisor=Simulator/' \
  "${TEST_ROLE_DIR}/tasks/cloudstack-zone-cluster.yml" \
  "${TEST_ROLE_DIR}/tasks/cloudstack-zone-host.yml"
# The Simulator's host discoverer requires a password unconditionally (real KVM's
# Libvirt discoverer doesn't - it uses the SSH-key trust set up in cloudstack-agent.yml),
# and only recognizes the magic URL http://sim as a discoverable resource - any real
# IP/hostname fails with "Cannot find the server resources".
sed -i \
  -e 's/username=cloudstack$/username=cloudstack\n    password=password/' \
  -e 's|url=http://{{ cloudstack_host_mgmt_ip }}|url=http://sim|' \
  "${TEST_ROLE_DIR}/tasks/cloudstack-zone-host.yml"

echo "==> Running provisioning playbook"
ansible-playbook "${ROLE_DIR}/tests/site.yml" \
  -i "${ROLE_DIR}/tests/inventory/simulator.yml" \
  -e "cloudstack_role_path=${TEST_ROLE_DIR}"

echo "==> Asserting final CloudStack state"
fail=0

check() {
  local desc="$1" want="$2"
  shift 2
  if cmk "$@" 2>/dev/null | grep -q "${want}"; then
    echo "  OK: ${desc}"
  else
    echo "  FAIL: ${desc} (expected to see '${want}')" >&2
    fail=1
  fi
}

zone_id="$(cmk list zones name=sim-zone-1 | jq -r '.zone[0].id')"
check "zone allocationstate=Enabled" '"allocationstate": "Enabled"' list zones name=sim-zone-1
check "host state=Up" '"state": "Up"' list hosts type=Routing zoneid="${zone_id}"
check "primary storage state=Up" '"state": "Up"' list storagepools name=sim-primary-1
check "secondary storage registered" '"name": "sim-secondary-1"' list imagestores name=sim-secondary-1

if [ "${fail}" -ne 0 ]; then
  echo "==> Simulator functional test FAILED" >&2
  exit 1
fi

echo "==> Simulator functional test passed"
