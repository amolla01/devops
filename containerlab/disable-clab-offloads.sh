#!/usr/bin/env bash
# disable-clab-offloads.sh — A/B test for the sonic-vs "checkerboard" dataplane drop.
#
# Disables NIC offloads (TSO/GSO/GRO/LRO + checksum) on every containerlab data
# interface inside each switch container's network namespace — i.e. the veth ends
# (ethN) AND the QEMU tap ends that bracket the sonic-vs software dataplane. This
# is the one credible offload-corruption fix for vrnetlab/containerlab fabrics.
#
# Run on the R810 host (the box running containerlab), as root:
#     sudo bash scripts/disable-clab-offloads.sh
# Re-enable / revert (no redeploy needed):
#     sudo bash scripts/disable-clab-offloads.sh --revert
#
# By default it targets the 8 fabric switches (spines, leaves, border-leaves).
# Pass a regex to widen, e.g. include hosts too:
#     sudo bash scripts/disable-clab-offloads.sh '' 'Spine-|Leaf-|Border-Leaf|k8s-|osh-|MonSrv'
#
# Uses the HOST ethtool via nsenter, so it does NOT depend on ethtool being
# present inside the launcher containers. Reversible; safe to run repeatedly.
set -uo pipefail

MODE="on"                       # "on" = offloads ON (revert); default disables them
case "${1:-}" in
  --revert|--on) MODE="on" ;;
  --off|"")      MODE="off" ;;
  *)             MODE="off" ;;
esac

NODE_RE="${2:-Spine-|Leaf-|Border-Leaf}"

# Offload features to toggle. tx/rx = checksum offload (the usual veth culprit).
FEATURES=(tso gso gro lro tx rx sg gso-partial)

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (needs nsenter + host ethtool)." >&2
  exit 1
fi
command -v nsenter  >/dev/null || { echo "ERROR: nsenter not found." >&2; exit 1; }
command -v ethtool  >/dev/null || { echo "ERROR: host ethtool not found (apt install ethtool)." >&2; exit 1; }

if [[ "$MODE" == "off" ]]; then
  echo "==> DISABLING offloads (${FEATURES[*]}) on interfaces matching switch containers: /$NODE_RE/"
else
  echo "==> RE-ENABLING offloads (${FEATURES[*]}) — reverting to defaults on: /$NODE_RE/"
fi

mapfile -t CONTAINERS < <(docker ps --format '{{.Names}}' | grep -E "$NODE_RE" || true)
if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
  echo "No running containers matched /$NODE_RE/. Is the lab deployed?" >&2
  exit 1
fi

toggle="$MODE"   # ethtool -K <if> <feat> on|off
total_if=0

for c in "${CONTAINERS[@]}"; do
  pid=$(docker inspect -f '{{.State.Pid}}' "$c" 2>/dev/null) || continue
  [[ -z "$pid" || "$pid" == "0" ]] && { echo "  ! $c: no PID (skipped)"; continue; }

  # Interfaces in the container netns, minus loopback and eth0 (OOB mgmt).
  mapfile -t IFS_LIST < <(nsenter -t "$pid" -n ip -o link show 2>/dev/null \
      | awk -F': ' '{print $2}' | cut -d'@' -f1 \
      | grep -vE '^(lo|eth0)$')

  echo "  $c (pid $pid): ${#IFS_LIST[@]} data iface(s) -> ${IFS_LIST[*]:-none}"
  for ifc in "${IFS_LIST[@]}"; do
    for f in "${FEATURES[@]}"; do
      nsenter -t "$pid" -n ethtool -K "$ifc" "$f" "$toggle" >/dev/null 2>&1
    done
    total_if=$((total_if+1))
  done
done

echo "==> Done. Toggled ${#FEATURES[@]} features -> $toggle on $total_if interface(s) across ${#CONTAINERS[@]} container(s)."
echo "    Verify one:  sudo nsenter -t \$(docker inspect -f '{{.State.Pid}}' Spine-S1) -n ethtool -k eth1 | grep -E 'tcp-seg|generic|checksum'"
echo "    Now re-run:  ansible-playbook -i inventory.yml playbooks/verify-fabric-ecmp.yml"
