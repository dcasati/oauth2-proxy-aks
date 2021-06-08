# oauth2-proxy-aks
Adding oath2-proxy in front of an ingress controller on AKS

# Setup the ingress controller 

1. Install the NGINX Ingress controller
```bash
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
```

1. Install cert-manager and attach to Lets Encrypt

```bash
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
```

1. create an issuer and apply it

```bash
cat >> cluster-issuer.yaml < EOF
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: diego@labzilla.org
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF

kubectl apply -f ../clusterIssuer/cluster-issuer.yaml 
```

1. create an ingress rule

```bash
cat << EOF > my-ingress.yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod 
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/auth-url: "https://auth.int.dcasati.net/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://auth.int.dcasati.net/oauth2/start?rd=https%3A%2F%2F$host$request_uri"
spec:
  tls:
   - hosts:
     - radar.int.dcasati.net
     secretName: tls-secret
  rules:
  - host: radar.int.dcasati.net
    http:
      paths: 
      - backend:
          serviceName: radar
          servicePort: 80
        path: /

```
# Generate the certificates

1. create a certificate 
```bash
cat >> certificate.yaml < EOF
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: tls-secret
  namespace: ingress-basic
spec:
  secretName: tls-secret
  dnsNames:
  - radar.int.dcasati.net
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - radar.int.dcasati.net
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
EOF
```

# Providers Example
## Github

1. setup your OAUTH on Github
1. create a Kubernetes secret with the values generated on step 1
Generate a random cookie secret:
```bash
python -c 'import os,base64; print base64.b64encode(os.urandom(16))'
```

Proceed with the creation of the Kubernetes Secret
```bash
# add your values here
YOUR_COOKIE_SECRET=
YOUR_GITHUB_CLIENT_ID=
YOUR_GITHUB_SECRET=

kubectl create secret generic oauth2-proxy-creds    \
--from-literal=cookie-secret=${YOUR_COOKIE_SECRET}  \
--from-literal=client-id=${YOUR_GITHUB_CLIENT_ID}   \
--from-literal=client-secret=${YOUR_GITHUB_SECRET}
```
1. generate a values file

```bash
cat << EOF > values.yaml
config:
  existingSecret: oauth2-proxy-creds

extraArgs:
  whitelist-domain: .int.mydomain.com
  cookie-domain: .int.mydomain.com
  provider: github
  github-org: "CloudNativeGBB" 

ingress:
  enabled: true
  path: /
  hosts:
    - auth.int.mydomain.com
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: oauth2-proxy-https-cert
      hosts:
        - auth.int.mydomain.com
EOF
```

1. install the oauth2-proxy with Helm based on your values file

```bash
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
helm upgrade oauth2-proxy/oauth2-proxy oauth-proxy --reuse-values --values oauth2-proxy-providers/gh/values.yaml
```
