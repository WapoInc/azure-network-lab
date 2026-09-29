# Bicep conversion

This directory is a local-module Bicep conversion of the root Terraform deployment and all 26 Terraform modules. It creates the resource group at subscription scope, then deploys resources through resource-group-scoped modules. It does not use remote Bicep registries.

## Prerequisites

- Azure CLI with Bicep CLI installed: `az version` and `az bicep version`
- An authenticated Azure session: `az login`
- Contributor (or equivalent resource deployment permissions) on the target subscription
- Permission to create subscription-scope deployments and resource groups
- Registered Azure resource providers used by the lab, including `Microsoft.Network`, `Microsoft.Compute`, `Microsoft.Storage`, and `Microsoft.OperationalInsights`
- Environment variables for subscription and VPN settings:

```bash
export AZURE_SUBSCRIPTION_ID='<subscription-guid>'
export AZURE_VPN_SHARED_KEY='<shared-key-or-placeholder-when-vpn-is-false>'
```

The deployment script prompts securely for `AZURE_ADMIN_PASSWORD`. It must contain 12-123 characters and satisfy at least three Azure complexity categories: uppercase, lowercase, number, and special character.

## Validate and preview

Run from the repository root. These commands do not deploy resources except the final `create` command.

```bash
az bicep build --file bicep-converted/main.bicep
az deployment sub validate \
  --name az700-lab-validate \
  --location southafricanorth \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --parameters bicep-converted/main.bicepparam
az deployment sub what-if \
  --name az700-lab-what-if \
  --location southafricanorth \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --parameters bicep-converted/main.bicepparam
```

Deploy only after reviewing the what-if result. The script can be run from any directory and prompts twice for the VM administrator password without displaying or storing it:

```bash
./bicep-converted/deploy.sh
```

## Terraform-to-Bicep mapping

| Terraform module | Bicep module |
| --- | --- |
| `application-gateway` | `modules/application-gateway/main.bicep` |
| `bastion` | `modules/bastion/main.bicep` |
| `dns-private-resolver` | `modules/dns-private-resolver/main.bicep` |
| `load-balancer` | `modules/load-balancer/main.bicep` |
| `local-network-gateway` | `modules/local-network-gateway/main.bicep` |
| `log-analytics` | `modules/log-analytics/main.bicep` |
| `nat-gateway` | `modules/nat-gateway/main.bicep` |
| `nsg` | `modules/nsg/main.bicep` |
| `private-dns-zone` | `modules/private-dns-zone/main.bicep` |
| `private-endpoint` | `modules/private-endpoint/main.bicep` |
| `resource-group` | `modules/resource-group/main.bicep` |
| `route-server` | `modules/route-server/main.bicep` |
| `storage-account` | `modules/storage-account/main.bicep` |
| `tags` | `modules/tags/main.bicep` |
| `vhub` | `modules/vhub/main.bicep` |
| `vhub-connection` | `modules/vhub-connection/main.bicep` |
| `vhub-firewall` | `modules/vhub-firewall/main.bicep` |
| `vhub-vpn-gateway` | `modules/vhub-vpn-gateway/main.bicep` |
| `vm-windows` | `modules/vm-windows/main.bicep` |
| `vm-windows-nva` | `modules/vm-windows-nva/main.bicep` |
| `vnet` | `modules/vnet/main.bicep` |
| `vnet-peering` | `modules/vnet-peering/main.bicep` |
| `vpn-connection` | `modules/vpn-connection/main.bicep` |
| `vpn-gateway` | `modules/vpn-gateway/main.bicep` |
| `vpn-site` | `modules/vpn-site/main.bicep` |
| `vwan` | `modules/vwan/main.bicep` |

Terraform association resources for subnet NSGs, subnet NAT Gateway attachment, and NIC load-balancer backend membership are represented as properties on their owning Bicep subnet or NIC resources. This is the native ARM/Bicep representation and preserves the resulting Azure configuration.

## Migration and cutover

Bicep does not adopt or import Terraform state automatically. Deploying Bicep against resources currently managed by Terraform can update those resources in Azure while Terraform continues to believe it owns them.

Recommended cutover:

1. Back up the Terraform state and record a clean `terraform plan`.
2. Stop Terraform automation and prevent concurrent applies.
3. Build and validate the Bicep template, then review subscription-scope `what-if` in full.
4. Confirm names and immutable properties match existing resources. Resolve any replacement actions before deployment.
5. Deploy Bicep once during an approved maintenance window.
6. Verify routing, BGP peers, VPN tunnels, DNS resolution, private endpoint connectivity, VM access, and edge-service health.
7. Retire or archive Terraform state only after the Bicep deployment is accepted as the management source.

The storage account name intentionally differs from Terraform. Terraform used a persisted random suffix; Bicep uses `uniqueString(subscription().id, resourceGroup().id, namePrefix)` for deterministic naming. For an existing storage account, this may produce a new name and therefore requires explicit migration planning.

The converted storage account also explicitly requires HTTPS, blocks Blob public access, and disables shared-key authorization. This lab uses the account through a private endpoint and does not consume account keys; enable shared-key access only if an external workload still requires it.

The default `ManagedBy` tag changes from `Terraform` to `Bicep`. A value supplied through `ctx.tags` still overrides the default.

Secrets are secure parameters and are never emitted as outputs. The Log Analytics workspace shared key is also not exposed.
