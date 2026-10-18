# Runbook

## Deploy

1. `cd examples/complete && cp terraform.tfvars.example terraform.tfvars`, set `public_access_cidrs` (your IP/32) and `admin_principal_arns`.
2. `terraform init`
3. Stage 1: `terraform apply -target=module.network -target=module.eks_cluster` (about 15 minutes).
4. Stage 2: `terraform apply` (Helm releases, about 5-10 minutes).
5. `$(terraform output -raw kubeconfig_command)` then `kubectl get nodes`.

## Access Argo CD and Grafana

```bash
$(terraform output -raw argocd_initial_admin_password_command)
$(terraform output -raw argocd_port_forward_command)            # http://localhost:8080
terraform output -raw grafana_admin_password                    # user: admin
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

## Upgrade Kubernetes

1. Bump `kubernetes_version` by one minor version (EKS only allows +1).
2. `terraform apply`: control plane first, then node groups roll (33% unavailable at a time).
3. Bump `addon_versions` if pinned, or leave unset to take the default for the new version.

## Destroy

```bash
kubectl delete ingress -A --all      # lets the Load Balancer Controller remove the ALB and its SGs
terraform destroy
```

If destroy hangs on the VPC, an ALB or security group created by the controller still exists: delete
resources tagged `elbv2.k8s.aws/cluster=<name>` in the console, then rerun `terraform destroy`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Kubernetes cluster unreachable` during plan | Cluster not created yet | Run the stage 1 targeted apply first |
| `Unauthorized` from kubectl | Your IAM principal has no access entry | Add its ARN to `admin_principal_arns` or keep `bootstrap_cluster_creator_admin_permissions = true` |
| Nodes stuck `NotReady` | vpc-cni add-on not active | `aws eks describe-addon --cluster-name <name> --addon-name vpc-cni` |
| Ingress has no address | LBC not running or subnets missing tags | `kubectl -n kube-system logs deploy/aws-load-balancer-controller`; check `kubernetes.io/role/elb` tags |
| EBS volumes stay `Pending` | EBS CSI Pod Identity association missing | `aws eks list-pod-identity-associations --cluster-name <name>` |
| Argo CD app `Unknown` | Repo URL or path wrong | Check `gitops_repo_url` and that `gitops/bootstrap` exists on `main` |
