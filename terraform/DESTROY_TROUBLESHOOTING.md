# Guide de Dépannage: Terraform Destroy

## Problème: Ressources non détruites après terraform destroy

Si vous rencontrez des problèmes où certaines ressources AWS ne sont pas détruites après `terraform destroy`, voici les solutions.

## Causes Communes

1. **Dépendances circulaires** entre ressources
2. **VPC Endpoints** qui bloquent la suppression du VPC
3. **Security Groups** avec des règles qui se référencent mutuellement
4. **ENI (Elastic Network Interfaces)** non détachées
5. **Clé KMS protégée** (comportement normal et souhaité)

## Solutions

### Solution 1: Destruction ciblée dans l'ordre

Détruisez les ressources dans l'ordre inverse de leur création:

```bash
cd terraform

# 1. Step Functions State Machine
terraform destroy -target=aws_sfn_state_machine.emr_pipeline

# 2. EMR Serverless Application
terraform destroy -target=aws_emrserverless_application.spark_app

# 3. EMR Security Configuration
terraform destroy -target=aws_emr_security_configuration.sec_cfg

# 4. ECS Task Definition et Cluster
terraform destroy -target=aws_ecs_task_definition.prep_task
terraform destroy -target=aws_ecs_cluster.main

# 5. VPC Endpoints (important!)
terraform destroy -target=module.vpc_endpoints

# 6. Security Groups
terraform destroy -target=aws_security_group.allow_access

# 7. VPC
terraform destroy -target=module.vpc_main

# 8. S3 Objects et Bucket
terraform destroy -target=aws_s3_object.certs_zip
terraform destroy -target=aws_s3_bucket.spark_results

# 9. IAM Roles et Policies
terraform destroy -target=aws_iam_role.sfn_role
terraform destroy -target=aws_iam_role.emr_serverless_job_role
terraform destroy -target=aws_iam_role.ecs_task_role
terraform destroy -target=aws_iam_role.ecs_execution_role

# 10. CloudWatch Logs
terraform destroy -target=aws_cloudwatch_log_group.ecs_prep

# 11. Tout le reste (sauf KMS)
terraform destroy
```

### Solution 2: Refresh désactivé

Si vous avez des erreurs de synchronisation d'état:

```bash
terraform destroy -refresh=false
```

### Solution 3: Suppression manuelle des ENI

Les ENI (Elastic Network Interfaces) peuvent rester attachées:

```bash
# Lister les ENI
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --region eu-west-3

# Détacher et supprimer chaque ENI
aws ec2 delete-network-interface \
  --network-interface-id <eni-id> \
  --region eu-west-3
```

### Solution 4: Suppression manuelle des VPC Endpoints

Les VPC Endpoints peuvent bloquer la suppression du VPC:

```bash
# Lister les VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --region eu-west-3

# Supprimer chaque endpoint
aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids <endpoint-id> \
  --region eu-west-3
```

### Solution 5: Suppression manuelle du VPC

Si le VPC refuse toujours de se supprimer:

```bash
# 1. Supprimer les sous-réseaux
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --region eu-west-3

aws ec2 delete-subnet --subnet-id <subnet-id> --region eu-west-3

# 2. Supprimer les route tables (sauf la principale)
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --region eu-west-3

aws ec2 delete-route-table --route-table-id <rt-id> --region eu-west-3

# 3. Détacher et supprimer l'Internet Gateway
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=<vpc-id>" \
  --region eu-west-3

aws ec2 detach-internet-gateway \
  --internet-gateway-id <igw-id> \
  --vpc-id <vpc-id> \
  --region eu-west-3

aws ec2 delete-internet-gateway \
  --internet-gateway-id <igw-id> \
  --region eu-west-3

# 4. Supprimer les Security Groups (sauf le default)
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --region eu-west-3

aws ec2 delete-security-group \
  --group-id <sg-id> \
  --region eu-west-3

# 5. Supprimer le VPC
aws ec2 delete-vpc --vpc-id <vpc-id> --region eu-west-3
```

### Solution 6: Nettoyer l'état Terraform

Si des ressources ont été supprimées manuellement mais restent dans l'état:

```bash
# Lister les ressources dans l'état
terraform state list

# Supprimer une ressource de l'état
terraform state rm <resource-address>

# Exemple:
terraform state rm module.vpc_main.aws_vpc.this[0]
```

## Script de Nettoyage Complet

Créez un script `cleanup.sh`:

```bash
#!/bin/bash
set -e

REGION="eu-west-3"
VPC_ID="<votre-vpc-id>"

echo "🧹 Nettoyage des ressources AWS..."

# 1. Supprimer les VPC Endpoints
echo "Suppression des VPC Endpoints..."
ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'VpcEndpoints[*].VpcEndpointId' \
  --output text \
  --region $REGION)

if [ ! -z "$ENDPOINTS" ]; then
  aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids $ENDPOINTS \
    --region $REGION
  echo "✅ VPC Endpoints supprimés"
fi

# 2. Supprimer les ENI
echo "Suppression des ENI..."
ENIS=$(aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[*].NetworkInterfaceId' \
  --output text \
  --region $REGION)

for ENI in $ENIS; do
  aws ec2 delete-network-interface \
    --network-interface-id $ENI \
    --region $REGION 2>/dev/null || true
done
echo "✅ ENI supprimées"

# 3. Attendre que les ressources soient détachées
echo "⏳ Attente de 30 secondes..."
sleep 30

# 4. Relancer terraform destroy
echo "Relancement de terraform destroy..."
cd terraform
terraform destroy -auto-approve

echo "✅ Nettoyage terminé!"
```

Rendez-le exécutable et lancez-le:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Prévention

Pour éviter ces problèmes à l'avenir:

1. **Utilisez des workspaces Terraform** pour isoler les environnements
2. **Documentez les dépendances** entre ressources
3. **Testez la destruction** dans un environnement de dev d'abord
4. **Utilisez des modules** pour encapsuler les ressources liées
5. **Activez les logs** pour diagnostiquer les problèmes

## Vérification Post-Destruction

Après la destruction, vérifiez qu'il ne reste aucune ressource:

```bash
# VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=emr-project" \
  --region eu-west-3

# Security Groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=emr_sg" \
  --region eu-west-3

# EMR Applications
aws emr-serverless list-applications --region eu-west-3

# ECS Clusters
aws ecs list-clusters --region eu-west-3

# Step Functions
aws stepfunctions list-state-machines --region eu-west-3

# S3 Buckets
aws s3 ls | grep sparkresults
```

## Note sur la Clé KMS

La clé KMS **ne sera jamais détruite** par `terraform destroy` car elle est protégée par `prevent_destroy = true`. C'est un comportement **normal et souhaité** pour éviter la perte de données chiffrées.

Pour gérer la clé KMS, consultez `KMS_MANAGEMENT.md`.

## Support

Si vous rencontrez toujours des problèmes:
1. Vérifiez les logs CloudWatch
2. Consultez la console AWS pour identifier les ressources bloquantes
3. Utilisez `terraform state list` pour voir l'état actuel
4. Contactez le support AWS si nécessaire
