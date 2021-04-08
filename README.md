# oauth2-proxy-aks
Adding oath2-proxy in front of an ingress controller on AKS


# Providers Example
## Github 
1. setup your OAUTH on Github
2. create a Kubernetes secret with the values generated on step 1

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
  whitelist-domain: .int.dcasati.net
  cookie-domain: .int.dcasati.net
  provider: github
  github-org: "CloudNativeGBB" 

ingress:
  enabled: true
  path: /
  hosts:
    - auth.int.dcasati.net
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: oauth2-proxy-https-cert
      hosts:
        - auth.int.dcasati.net
EOF
```

3. install the oauth2-proxy with Helm based on your values file

```bash
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
helm upgrade oauth2-proxy/oauth2-proxy oauth-proxy --reuse-values --values oauth2-proxy-providers/gh/values.yaml
```
