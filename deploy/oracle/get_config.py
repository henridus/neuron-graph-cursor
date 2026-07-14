"""Read-only OCI inventory for atlas-hermes. Launches nothing.

Prints existing VCN / subnet / image / AD OCIDs so the catcher reuses them
instead of recreating network resources. Does not print user/tenancy secrets.
"""
from __future__ import annotations

import oci

CONFIG = r"C:\Users\henri\.oci\config"
DISPLAY = "atlas-hermes"


def tail(ocid: str, n: int = 20) -> str:
    return "..." + ocid[-n:] if ocid else "<none>"


def main() -> None:
    cfg = oci.config.from_file(CONFIG)
    tenancy = cfg["tenancy"]
    identity = oci.identity.IdentityClient(cfg)
    net = oci.core.VirtualNetworkClient(cfg)
    compute = oci.core.ComputeClient(cfg)

    print(f"region={cfg.get('region')}")

    ads = identity.list_availability_domains(tenancy).data
    print(f"ADs={[a.name for a in ads]}")

    vcns = [v for v in net.list_vcns(tenancy).data if v.display_name == f"{DISPLAY}-vcn"]
    if not vcns:
        print("VCN=<missing>")
        return
    vcn = vcns[0]
    print(f"VCN.name={vcn.display_name} VCN.id={tail(vcn.id)} state={vcn.lifecycle_state}")

    subs = net.list_subnets(tenancy, vcn_id=vcn.id).data
    for s in subs:
        print(
            f"SUBNET.name={s.display_name} id={tail(s.id)} "
            f"public={not s.prohibit_public_ip_on_vnic}"
        )

    imgs = compute.list_images(
        tenancy,
        operating_system="Canonical Ubuntu",
        operating_system_version="22.04",
        shape="VM.Standard.A1.Flex",
        sort_by="TIMECREATED",
        sort_order="DESC",
    ).data
    if imgs:
        img = next((i for i in imgs if "aarch64" in (i.display_name or "").lower()), imgs[0])
        print(f"IMAGE.name={img.display_name} id={tail(img.id)}")

    insts = [
        i
        for i in compute.list_instances(tenancy, display_name=DISPLAY).data
        if i.lifecycle_state not in ("TERMINATED", "TERMINATING")
    ]
    if insts:
        for i in insts:
            print(f"INSTANCE.name={i.display_name} state={i.lifecycle_state} id={tail(i.id)}")
    else:
        print("INSTANCE=<none running>")


if __name__ == "__main__":
    main()
