"""Polite Always Free A1 capacity catcher (Zurich, single AD).

Reuses the existing network (verified read-only by get_config.py): it does NOT
create VCN/subnet. Loops launch_instance with a polite interval and stops on
non-transient errors. No secrets are printed.

Patterns inspired by public OCI ARM catchers (alexpua/oci-arm-catcher), coded
in-repo — no unaudited third-party binary imported.

Usage:
    uvx --with oci python deploy/oracle/catch_a1.py
Stop with Ctrl+C. Safe to re-run: it exits early if an instance already exists.
"""
from __future__ import annotations

import time
from datetime import datetime
from pathlib import Path

import oci

CONFIG = r"C:\Users\henri\.oci\config"
SSH_PUB = Path(r"C:\Users\henri\.ssh\atlas_oracle.pub")
LOG_FILE = Path(__file__).with_name("catch_a1.log")
DISPLAY = "atlas-hermes"

OCPUS = 1.0
MEMORY_GB = 6.0
BOOT_GB = 50
POLL_SEC = 300          # polite interval between capacity retries
BACKOFF_429_SEC = 600   # longer wait when rate-limited
MAX_ATTEMPTS = 0        # 0 = infinite (run in background until caught)

# Transient service errors worth retrying on.
TRANSIENT = {
    (500, "capacity"),
    (500, "internalerror"),
    (500, "out of host capacity"),
}


def log(msg: str) -> None:
    line = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}"
    print(line, flush=True)
    with LOG_FILE.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def is_transient(err: "oci.exceptions.ServiceError") -> bool:
    msg = (err.message or "").lower()
    if err.status == 429:
        return True
    if err.status == 500 and ("capacity" in msg or "internalerror" in msg or "internal error" in msg):
        return True
    if err.status == 503:
        return True
    return False


def resolve_public_ip(compute, net, tenancy, inst):
    for att in compute.list_vnic_attachments(tenancy, instance_id=inst.id).data:
        if not att.vnic_id:
            continue
        vnic = net.get_vnic(att.vnic_id).data
        if vnic.public_ip:
            return vnic.public_ip
    return None


def main() -> None:
    cfg = oci.config.from_file(CONFIG)
    tenancy = cfg["tenancy"]
    identity = oci.identity.IdentityClient(cfg)
    net = oci.core.VirtualNetworkClient(cfg)
    compute = oci.core.ComputeClient(cfg)

    ad = identity.list_availability_domains(tenancy).data[0].name
    ssh_key = SSH_PUB.read_text(encoding="utf-8").strip()
    if not ssh_key.startswith("ssh-"):
        raise SystemExit("Invalid SSH public key")

    vcn = next(
        (v for v in net.list_vcns(tenancy).data if v.display_name == f"{DISPLAY}-vcn"),
        None,
    )
    if vcn is None:
        raise SystemExit("VCN atlas-hermes-vcn missing — run provision_a1.py once to build network")
    subnet = next(
        (s for s in net.list_subnets(tenancy, vcn_id=vcn.id).data if s.display_name == f"{DISPLAY}-public"),
        None,
    )
    if subnet is None:
        raise SystemExit("Subnet atlas-hermes-public missing — run provision_a1.py once")

    existing = [
        i
        for i in compute.list_instances(tenancy, display_name=DISPLAY).data
        if i.lifecycle_state in ("RUNNING", "PROVISIONING", "STARTING")
    ]
    if existing:
        inst = existing[0]
        ip = resolve_public_ip(compute, net, tenancy, inst)
        log(f"INSTANCE_EXISTS state={inst.lifecycle_state} PUBLIC_IP={ip} — nothing to catch")
        return

    images = compute.list_images(
        tenancy,
        operating_system="Canonical Ubuntu",
        operating_system_version="22.04",
        shape="VM.Standard.A1.Flex",
        sort_by="TIMECREATED",
        sort_order="DESC",
    ).data
    image = next((i for i in images if "aarch64" in (i.display_name or "").lower()), images[0])

    launch = oci.core.models.LaunchInstanceDetails(
        availability_domain=ad,
        compartment_id=tenancy,
        display_name=DISPLAY,
        shape="VM.Standard.A1.Flex",
        shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
            ocpus=OCPUS, memory_in_gbs=MEMORY_GB
        ),
        source_details=oci.core.models.InstanceSourceViaImageDetails(
            source_type="image", image_id=image.id, boot_volume_size_in_gbs=BOOT_GB
        ),
        create_vnic_details=oci.core.models.CreateVnicDetails(
            subnet_id=subnet.id, assign_public_ip=True, display_name=f"{DISPLAY}-vnic"
        ),
        metadata={"ssh_authorized_keys": ssh_key},
    )

    log(f"Catcher start AD={ad} shape=A1.Flex {OCPUS}OCPU/{MEMORY_GB}GB image={image.display_name}")
    attempt = 0
    while True:
        attempt += 1
        try:
            inst = compute.launch_instance(launch).data
            log(f"LAUNCH_ACCEPTED id=...{inst.id[-16:]} — waiting RUNNING")
            inst = oci.wait_until(
                compute,
                compute.get_instance(inst.id),
                "lifecycle_state",
                "RUNNING",
                max_wait_seconds=900,
            ).data
            ip = resolve_public_ip(compute, net, tenancy, inst)
            log("=" * 48)
            log(f"CAUGHT! INSTANCE_RUNNING id=...{inst.id[-16:]} PUBLIC_IP={ip}")
            log(f"SSH: ssh -i C:\\Users\\henri\\.ssh\\atlas_oracle ubuntu@{ip}")
            log("=" * 48)
            return
        except oci.exceptions.ServiceError as err:
            reason = f"{err.status} {(err.message or '')[:60]}"
            if is_transient(err):
                wait = BACKOFF_429_SEC if err.status == 429 else POLL_SEC
                log(f"attempt {attempt}: transient [{reason}] — sleep {wait}s")
            else:
                log(f"attempt {attempt}: NON-TRANSIENT [{reason}] — abort")
                raise SystemExit(1)
        except KeyboardInterrupt:
            log("Interrupted by user — stopping catcher")
            return
        if MAX_ATTEMPTS and attempt >= MAX_ATTEMPTS:
            log(f"Reached MAX_ATTEMPTS={MAX_ATTEMPTS} without capacity — stop")
            return
        time.sleep(wait)


if __name__ == "__main__":
    main()
