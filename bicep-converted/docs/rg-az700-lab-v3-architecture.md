# rg-az700-lab-v3 deployment architecture

- Subscription: `0cfd0d2a-2b38-4c93-ba14-cf79185bc683`
- Region: `southafricanorth`
- Source: `bicep-converted/main.bicep` and `main.bicepparam`
- Current desired state: **63 ARM resources**

## Resource inventory

| Area | ARM resources deployed | Count |
| --- | --- | ---: |
| Scope | Resource group `rg-az700-lab-v3` | 1 |
| Monitoring | Log Analytics workspace `log-az700-lab` | 1 |
| Security | NSGs `nsg-spoke1-az700-lab`, `nsg-spoke2-az700-lab`, `nsg-onprem-az700-lab` | 3 |
| NAT | Public IP `nat-az700-lab-pip`; NAT Gateway `nat-az700-lab` | 2 |
| Virtual networks | `vnet-spoke1-az700-lab`, `vnet-spoke2-az700-lab`, `vnet-onprem-az700-lab` | 3 |
| Subnets | Spoke 1 (9), Spoke 2 (1), on-prem simulation (3) | 13 |
| Peering | `peer-spoke1-to-spoke2`, `peer-spoke2-to-spoke1` | 2 |
| Virtual WAN | `vwan-az700-lab`; `vhub-az700-lab` | 2 |
| Secured hub | Firewall policy, rule collection group, Azure Firewall, routing intent | 4 |
| Hub connection | `conn-spoke2-az700-lab` | 1 |
| Route Server | Public IP, Route Server, IP configuration, BGP connection | 4 |
| Private DNS | Zones `lab.internal` and `privatelink.blob.core.windows.net`; three VNet links per zone | 8 |
| DNS Resolver | Resolver plus inbound and outbound endpoints | 3 |
| Load balancing | Internal Standard Load Balancer `ilb-az700-lab` (frontend, pool, probe, and rule are inline properties) | 1 |
| Storage | Standard LRS StorageV2 account `st<unique>` | 1 |
| Private Link | Private Endpoint `pe-storage-az700-lab`; private DNS zone group | 2 |
| Workload compute | Three NICs and VMs: `vm-spoke1-1`, `vm-spoke1-2`, `vm-spoke2-1` | 6 |
| NVA compute | Two NICs, VMs, and RRAS extensions: `vm-spoke1-nva`, `vm-onprem-nva` | 6 |
| **Total** | | **63** |

## Address plan

| Network | Address space | Subnets |
| --- | --- | --- |
| Virtual Hub | `10.10.0.0/23` | Azure-managed hub addressing |
| Spoke 1 | `10.1.0.0/16` | Workload `10.1.1.0/24`; App Gateway `10.1.2.0/24`; Bastion `10.1.3.0/26`; Private Endpoint `10.1.4.0/24`; DNS inbound `10.1.5.0/28`; DNS outbound `10.1.5.16/28`; Load Balancer `10.1.6.0/24`; Route Server `10.1.7.0/27`; NVA `10.1.8.0/24` |
| Spoke 2 | `10.2.0.0/16` | Workload `10.2.1.0/24` |
| On-prem simulation | `192.168.0.0/16` | Gateway `192.168.0.0/27`; Default `192.168.1.0/24`; NVA `192.168.2.0/24` |

## Significant relationships

| Source | Connection | Destination |
| --- | --- | --- |
| `vwan-az700-lab` | Contains | `vhub-az700-lab` |
| `vhub-az700-lab` | Secured by policy and routing intent | `fw-vhub-az700-lab` |
| `vhub-az700-lab` | Hub VNet connection | Spoke 2 |
| Spoke 1 | Bidirectional VNet peering | Spoke 2 |
| `vm-spoke1-nva` (`10.1.8.10`, ASN 65501) | BGP | Route Server (ASN 65515) |
| Spoke 1 Workload subnet | NAT association | `nat-az700-lab` and its Public IP |
| `ilb-az700-lab` | Backend pool | `vm-spoke1-1`, `vm-spoke1-2` |
| Storage Blob | Private Link | `pe-storage-az700-lab` |
| Private Endpoint | DNS zone group | `privatelink.blob.core.windows.net` |
| Both private DNS zones | VNet links | Spoke 1, Spoke 2, on-prem simulation |
| DNS Resolver | Inbound/outbound endpoints | Spoke 1 delegated DNS subnets |

## Disabled by current parameters

| Feature | Resources not deployed |
| --- | --- |
| VPN | vHub VPN Gateway, on-prem VPN Gateway and Public IP, VPN site, Local Network Gateway, and VPN connections |
| Application Gateway | WAF_v2 Application Gateway and Public IP |
| Bastion | Basic Bastion host and Public IP |
| On-prem workload VM | `vm-onprem-1` and NIC |
| Spoke 1 vHub connection | Disabled because Route Server mode is enabled |

## Diagram

- Editable: [rg-az700-lab-v3-architecture.drawio](rg-az700-lab-v3-architecture.drawio)
- Rendered: [rg-az700-lab-v3-architecture.png](rg-az700-lab-v3-architecture.png)

The Log Analytics workspace is deployed but no diagnostic settings connect resources to it in the current template. The on-prem simulation VNet has private DNS links but no VPN or VNet peering path to the spokes with the current flags.
