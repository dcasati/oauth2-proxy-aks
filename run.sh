#!/usr/bin/env bash

YOUR_COOKIE_SECRET=
YOUR_GITHUB_CLIENT_ID=
YOUR_GITHUB_SECRET=

# Create a namespace for your ingress resources
kubectl create namespace ingress-basic

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Use Helm to deploy an NGINX ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-basic \
    --set controller.replicaCount=1 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux

# Label the ingress-basic namespace to disable resource validation
kubectl label namespace ingress-basic cert-manager.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
  --namespace ingress-basic \
  --set installCRDs=true \
  --set nodeSelector."kubernetes\.io/os"=linux \
  --set webhook.nodeSelector."kubernetes\.io/os"=linux \
  --set cainjector.nodeSelector."kubernetes\.io/os"=linux \
  --version v0.16.1

kubectl apply -f ../clusterIssuer/cluster-issuer.yaml

sleep 30
kubectl apply -f ingress.yaml

# create the kubernetes secret that hold the OAUTH information for provider
kubectl create secret generic oauth2-proxy-creds \
--from-literal=cookie-secret=$YOUR_COOKIE_SECRET \
--from-literal=client-id=$YOUR_GITHUB_CLIENT_ID \
--from-literal=client-secret=$YOUR_GITHUB_SECRET

helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
helm upgrade oauth2-proxy/oauth2-proxy oauth-proxy --reuse-values --values oauth2-proxy-providers/values.yaml
