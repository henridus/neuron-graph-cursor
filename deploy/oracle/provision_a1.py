"""Provision Always Free A1 VM + minimal VCN in OCI. No secrets printed."""
from __future__ import annotations

import time

import oci
from pathlib import Path

CONFIG = r"C:\Users\henri\.oci\config"
SSH_PUB = Path(r"C:\Users\henri\.ssh\atlas_oracle.pub")
DISPLAY = "atlas-hermes"
# Always Free A1 updated limits (banner 2026): max 2 OCPU / 12 GB.
# Start smaller — Zurich often returns "Out of host capacity" on 2/12.
OCPUS = 1.0
MEMORY_GB = 6.0
MAX_RETRIES = 5
RETRY_SLEEP_SEC = 45


def main() -> None:
    cfg = oci.config.from_file(CONFIG)
    tenancy = cfg["tenancy"]
    identity = oci.identity.IdentityClient(cfg)
    net = oci.core.VirtualNetworkClient(cfg)
    compute = oci.core.ComputeClient(cfg)

    ads = identity.list_availability_domains(tenancy).data
    if not ads:
        raise SystemExit("No availability domain")
    ad = ads[0].name
    print(f"AD={ad}")

    ssh_key = SSH_PUB.read_text(encoding="utf-8").strip()
    if not ssh_key.startswith("ssh-"):
        raise SystemExit("Invalid SSH public key")

    vcns = net.list_vcns(tenancy).data
    vcn = next((v for v in vcns if v.display_name == f"{DISPLAY}-vcn"), None)
    if vcn is None:
        print("Creating VCN...")
        vcn = net.create_vcn(
            oci.core.models.CreateVcnDetails(
                cidr_block="10.0.0.0/16",
                compartment_id=tenancy,
                display_name=f"{DISPLAY}-vcn",
                dns_label="atlashermes",
            )
        ).data
        vcn = oci.wait_until(
            net, net.get_vcn(vcn.id), "lifecycle_state", "AVAILABLE"
        ).data
    print(f"VCN={vcn.id[-16:]}")

    igws = net.list_internet_gateways(tenancy, vcn_id=vcn.id).data
    igw = next((g for g in igws if g.display_name == f"{DISPLAY}-igw"), None)
    if igw is None:
        print("Creating Internet Gateway...")
        igw = net.create_internet_gateway(
            oci.core.models.CreateInternetGatewayDetails(
                compartment_id=tenancy,
                vcn_id=vcn.id,
                display_name=f"{DISPLAY}-igw",
                is_enabled=True,
            )
        ).data
        igw = oci.wait_until(
            net, net.get_internet_gateway(igw.id), "lifecycle_state", "AVAILABLE"
        ).data

    rt_id = vcn.default_route_table_id
    rt = net.get_route_table(rt_id).data
    has_default = any(r.destination == "0.0.0.0/0" for r in (rt.route_rules or []))
    if not has_default:
        print("Updating route table 0.0.0.0/0 -> IGW...")
        rules = list(rt.route_rules or [])
        rules.append(
            oci.core.models.RouteRule(
                cidr_block=None,
                destination="0.0.0.0/0",
                destination_type="CIDR_BLOCK",
                network_entity_id=igw.id,
            )
        )
        net.update_route_table(
            rt_id, oci.core.models.UpdateRouteTableDetails(route_rules=rules)
        )

    sl_id = vcn.default_security_list_id
    sl = net.get_security_list(sl_id).data
    ingress = list(sl.ingress_security_rules or [])
    has_ssh = any(
        r.protocol == "6"
        and r.tcp_options
        and r.tcp_options.destination_port_range
        and r.tcp_options.destination_port_range.min == 22
        for r in ingress
    )
    if not has_ssh:
        print("Adding SSH ingress tcp/22...")
        ingress.append(
            oci.core.models.IngressSecurityRule(
                protocol="6",
                source="0.0.0.0/0",
                source_type="CIDR_BLOCK",
                tcp_options=oci.core.models.TcpOptions(
                    destination_port_range=oci.core.models.PortRange(min=22, max=22)
                ),
                description="SSH",
            )
        )
        net.update_security_list(
            sl_id,
            oci.core.models.UpdateSecurityListDetails(ingress_security_rules=ingress),
        )

    subs = net.list_subnets(tenancy, vcn_id=vcn.id).data
    subnet = next((s for s in subs if s.display_name == f"{DISPLAY}-public"), None)
    if subnet is None:
        print("Creating public subnet...")
        subnet = net.create_subnet(
            oci.core.models.CreateSubnetDetails(
                cidr_block="10.0.1.0/24",
                compartment_id=tenancy,
                vcn_id=vcn.id,
                display_name=f"{DISPLAY}-public",
                dns_label="public",
                route_table_id=rt_id,
                security_list_ids=[sl_id],
                prohibit_public_ip_on_vnic=False,
            )
        ).data
        subnet = oci.wait_until(
            net, net.get_subnet(subnet.id), "lifecycle_state", "AVAILABLE"
        ).data
    print(f"SUBNET={subnet.id[-16:]}")

    existing = compute.list_instances(tenancy, display_name=DISPLAY).data
    running = [i for i in existing if i.lifecycle_state in ("RUNNING", "PROVISIONING", "STARTING")]
    if running:
        inst = running[0]
        print(f"INSTANCE_EXISTS state={inst.lifecycle_state} id=...{inst.id[-16:]}")
    else:
        images = compute.list_images(
            tenancy,
            operating_system="Canonical Ubuntu",
            operating_system_version="22.04",
            shape="VM.Standard.A1.Flex",
            sort_by="TIMECREATED",
            sort_order="DESC",
        ).data
        image = next((i for i in images if "aarch64" in (i.display_name or "").lower()), images[0])
        print(f"IMAGE={image.display_name}")

        print(f"Launching instance shape A1.Flex {OCPUS} OCPU / {MEMORY_GB} GB...")
        launch = oci.core.models.LaunchInstanceDetails(
            availability_domain=ad,
            compartment_id=tenancy,
            display_name=DISPLAY,
            shape="VM.Standard.A1.Flex",
            shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
                ocpus=OCPUS, memory_in_gbs=MEMORY_GB
            ),
            source_details=oci.core.models.InstanceSourceViaImageDetails(
                source_type="image", image_id=image.id, boot_volume_size_in_gbs=50
            ),
            create_vnic_details=oci.core.models.CreateVnicDetails(
                subnet_id=subnet.id,
                assign_public_ip=True,
                display_name=f"{DISPLAY}-vnic",
            ),
            metadata={"ssh_authorized_keys": ssh_key},
        )
        last_err = None
        inst = None
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                print(f"Attempt {attempt}/{MAX_RETRIES}...")
                inst = compute.launch_instance(launch).data
                break
            except oci.exceptions.ServiceError as err:
                last_err = err
                msg = (err.message or "").lower()
                if err.status == 500 and "capacity" in msg:
                    print(f"Out of capacity, sleep {RETRY_SLEEP_SEC}s...")
                    time.sleep(RETRY_SLEEP_SEC)
                    continue
                raise
        if inst is None:
            raise last_err  # type: ignore[misc]
        inst = oci.wait_until(
            compute,
            compute.get_instance(inst.id),
            "lifecycle_state",
            "RUNNING",
            max_wait_seconds=900,
        ).data
        print(f"INSTANCE_RUNNING id=...{inst.id[-16:]}")

    vnics = compute.list_vnic_attachments(tenancy, instance_id=inst.id).data
    public_ip = None
    for att in vnics:
        if not att.vnic_id:
            continue
        vnic = net.get_vnic(att.vnic_id).data
        public_ip = vnic.public_ip
        if public_ip:
            break
    print(f"PUBLIC_IP={public_ip}")
    print(f"SSH=ssh -i C:\\\\Users\\\\henri\\\\.ssh\\\\atlas_oracle ubuntu@{public_ip}")


if __name__ == "__main__":
    main()
