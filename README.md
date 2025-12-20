# gke-hybrid-autonomy
A high-availability hybrid cloud framework orchestrating GKE Autopilot from an edge Ubuntu controller. Built with a focus on Site Reliability Engineering (SRE) principles, featuring SLO-based alerting, automated toil reduction, and eBPF-powered observability.

# Progress: Phase 1 Complete (The Probe Agent)
The core monitoring component is now implemented and containerized.

Features:
Go-based Probe: Measures real-time latency to target endpoints.

Prometheus Integration: Exposes standard Go metrics and custom latency gauges on :8080/metrics.

Containerized Workload: Uses a Multi-Stage Dockerfile to produce a minimal (~15MB) production-ready image.

Local Verification
To run the probe agent locally using Docker:

# 1. Build the image
DOCKER_BUILDKIT=0 docker build -t probe-agent:v1 .

# 2. Run the container
docker run -p 8080:8080 probe-agent:v1

Verification (SRE Proof)
Once the container is running, verify the metrics stream using curl:

Bash

curl localhost:8080/metrics | grep hybrid_link_latency_ms
Expected output: hybrid_link_latency_ms <value>

## 🚀 Progress: Phase 2 Complete (Cloud Orchestration)

The framework has moved from local simulation to a live Google Cloud environment.

### Infrastructure & Deployment
- **IaC:** Provisioned a **GKE Autopilot** cluster using **Terraform**, ensuring a hands-off, SRE-focused management layer.
- **Artifact Management:** Established a secure private registry using **Google Artifact Registry** for image lifecycle management.
- **Orchestration:** Implemented Kubernetes manifests with defined **Resource Requests/Limits** to ensure workload stability.

### Live Cloud Verification
The probe is currently running in `europe-west3` (Frankfurt). Verified via:
```bash
kubectl logs -l app=probe
