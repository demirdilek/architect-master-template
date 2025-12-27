#!/bin/bash
echo "Refresing Kubeconfigs..."
gcloud container clusters get-credentials gke-frankfurt-autopilot --region europe-west3
aws eks update-kubeconfig --region eu-central-1 --name eks-frankfurt-worker
az aks get-credentials --resource-group hybrid-project-rg --name aks-frankfurt-backup
echo "Done! Ready to rock across 3 clouds."