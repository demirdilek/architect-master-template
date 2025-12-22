# 🚀 GKE Hybrid Autonomy Framework

A high-availability hybrid cloud framework orchestrating **GKE Autopilot** as the primary control hub, with **AWS EKS** and **Azure AKS** providing cross-cloud resilience. Built with SRE principles, featuring non-overlapping networking, OIDC identity federation, and automated infrastructure provisioning.

---

## 🏗️ Multi-Cloud Fleet Architecture
The "Reliability Trio" is distributed across Frankfurt-based data centers to ensure zero downtime and vendor independence.

| Context | Provider | Region | Managed Service | Role |
| :--- | :--- | :--- | :--- | :--- |
| `gcp-main` | **Google Cloud** | europe-west3 | GKE Autopilot | Fleet Manager & Frontend |
| `aws-worker` | **AWS** | eu-central-1 | EKS Auto Mode | Inventory & Analytics |
| `azure-backup` | **Azure** | germanywestcentral | AKS (v6 Arch) | Disaster Recovery (DR) |

### 🌐 Networking Strategy (Non-Overlapping CIDRs)
To ensure cross-cloud communication without routing conflicts, a strict CIDR plan was implemented:

| Cloud | Network Resource | CIDR Range | Role |
| :--- | :--- | :--- | :--- |
| **GCP** | VPC (Auto) | `10.128.0.0/20` | Primary Orchestration |
| **AWS** | VPC (Manual) | `10.2.0.0/16` | Data & Processing |
| **Azure** | VNet (Manual) | `10.3.0.0/16` | Emergency Failover |

---

### 🛠️ Critical Troubleshooting & Fixes

#### 1. AWS EKS: Identity Access Management (IAM)
**Issue:** `kubectl` returned authentication errors despite active AWS CLI sessions.
**The Fix:** Registered the IAM user in the EKS Access Entry system and associated the correct Admin Policy. Note the specific `eks` prefix required for the ARN.

```bash
# Register the IAM user
aws eks create-access-entry \
    --cluster-name eks-frankfurt-worker \
    --principal-arn arn:aws:iam::509452097369:user/terraform-manager \
    --region eu-central-1 \
    --type STANDARD

# Associate the Admin Policy (Note the specific EKS-prefix ARN!)
aws eks associate-access-policy \
    --cluster-name eks-frankfurt-worker \
    --principal-arn arn:aws:iam::509452097369:user/terraform-manager \
    --region eu-central-1 \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster
```
2. Azure: Resource Quota & SKU Audit
Issue: Provisioning failed for Standard_DS2_v2 in germanywestcentral.

Solution: Performed a CLI-based SKU audit and migrated to the Standard_D2s_v6 architecture to comply with regional subscription constraints.

3. Local Environment: Xubuntu (XFCE) Fix
Issue: Desktop content "shifts" or follows the mouse cursor (Viewport Panning).

Cause: Accidental trigger of Alt + Mouse Scroll (XFCE Zoom).

Fix: Used Alt + Scroll Down to reset. Permanent fix: Disabled Zoom in Settings -> Window Manager -> Keyboard.

🚀 Fleet Operations
To verify the health of all three clusters simultaneously:
```bash
for ctx in gcp-main aws-worker azure-backup; do 
  echo "--- 🚀 Cluster: $ctx ---"
  kubectl --context=$ctx get nodes
  echo ""
done
```
## 📈 Implementation History

### Phase 1: The Probe Agent (Local)
* **Real-time Monitoring:** Developed a Go-based Probe for latency tracking.
* **Metrics:** Exposed metrics on `:8080/metrics` for Prometheus integration.
* **Optimization:** Containerized using a multi-stage Dockerfile (~15MB image).

### Phase 2: Cloud Orchestration (GCP)
* **Provisioning:** Deployed GKE Autopilot via Terraform for zero-ops management.
* **Storage:** Established secure Artifact Registry for private image hosting.
* **Validation:** Verified workload stability via `kubectl logs -l app=probe`.

### Phase 3: Multi-Cloud Expansion
* **Identity Federation:** Utilized OIDC via GKE Hub authority for native cross-cloud authentication.
* **Provider Dependencies:** Resolved Terraform race conditions using `depends_on` blocks for OIDC issuer URLs.
* **API Provisioning:** Managed GKE stabilization with custom Terraform timeouts (30m).