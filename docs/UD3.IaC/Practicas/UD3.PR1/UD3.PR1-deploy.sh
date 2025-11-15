#!/bin/bash
echo "🚀 Iniciando despliegue de la infraestructura Canary (HTTP)..."

# --- VARIABLES (Personaliza esto) ---
VPC_ID="vpc-xxxxxxxx"                 # ID de tu VPC por defecto
SUBNET_IDS="subnet-aaaaaaa,subnet-bbbbbbb" # IDs de 2 subredes PÚBLICAS (separadas por coma)
KEY_NAME="tu-key-pair"                # Tu par de claves EC2 para SSH
MY_IP="xx.xx.xx.xx/32"                # Tu IP pública (para SSH)
DOMAIN_NAME="aws.tudominio.com"       # El subdominio a delegar
APP_URL="app.${DOMAIN_NAME}"          # La URL final de la app
AMI_ID="ami-0abcdef123456"            # Busca el ID de "Amazon Linux 2023 AMI" en tu región

# Fichero para guardar los IDs de los recursos creados
STATE_FILE="stack.vars"

echo "--- 1. Creando Grupos de Seguridad (SG) ---"
SG_ALB_ID=$(aws ec2 create-security-group \
  --group-name SG-ELB-Publico-CLI \
  --description "SG para ALB - CLI" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
# Regla para el ALB (Solo HTTP)
aws ec2 authorize-security-group-ingress --group-id $SG_ALB_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 [cite: 35-36]
echo "SG del ALB creado: $SG_ALB_ID"

SG_EC2_ID=$(aws ec2 create-security-group \
  --group-name SG-Servidores-Privado-CLI \
  --description "SG para EC2 - CLI" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
# Reglas para las Instancias (SSH desde mi IP, HTTP solo desde el ALB)
aws ec2 authorize-security-group-ingress --group-id $SG_EC2_ID --protocol tcp --port 22 --cidr $MY_IP [cite: 41-42]
aws ec2 authorize-security-group-ingress --group-id $SG_EC2_ID --protocol tcp --port 80 --source-group $SG_ALB_ID [cite: 43-44]
echo "SG de Instancias creado: $SG_EC2_ID"

echo "--- 2. Creando Zona Alojada (Route 53) ---"
ZONE_ID_OUTPUT=$(aws route53 create-hosted-zone --name $DOMAIN_NAME --caller-reference $(date +%s))
HOSTED_ZONE_ID=$(echo $ZONE_ID_OUTPUT | jq -r '.HostedZone.Id' | cut -d'/' -f3)
NS_SERVERS=$(echo $ZONE_ID_OUTPUT | jq -r '.DelegationSet.NameServers | @json')
echo "Zona Alojada Creada: $HOSTED_ZONE_ID" [cite: 116-119]

echo "--- 3. Creando Instancias EC2 (Estable y Canary) ---"
INSTANCE_STABLE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_EC2_ID \
  --user-data file://user-data-stable.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Servidor-Estable-CLI}]' \
  --query 'Instances[0].InstanceId' --output text) [cite: 49-56]
echo "Instancia Estable creada: $INSTANCE_STABLE_ID"

INSTANCE_CANARY_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_EC2_ID \
  --user-data file://user-data-canary.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Servidor-Canary-CLI}]' \
  --query 'Instances[0].InstanceId' --output text) [cite: 69-76]
echo "Instancia Canary creada: $INSTANCE_CANARY_ID"

echo "--- 4. Creando Grupos de Destino (Target Groups) ---"
TG_STABLE_ARN=$(aws elbv2 create-target-group \
  --name TG-Estable-CLI \
  --protocol HTTP --port 80 \
  --vpc-id $VPC_ID \
  --query 'TargetGroups[0].TargetGroupArn' --output text) [cite: 92-94]
echo "TG Estable creado: $TG_STABLE_ARN"

TG_CANARY_ARN=$(aws elbv2 create-target-group \
  --name TG-Canary-CLI \
  --protocol HTTP --port 80 \
  --vpc-id $VPC_ID \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "TG Canary creado: $TG_CANARY_ARN"

echo "⏳ Esperando a que las instancias estén 'running' para registrarlas..."
aws ec2 wait instance-running --instance-ids $INSTANCE_STABLE_ID $INSTANCE_CANARY_ID

aws elbv2 register-targets --target-group-arn $TG_STABLE_ARN --targets Id=$INSTANCE_STABLE_ID
aws elbv2 register-targets --target-group-arn $TG_CANARY_ARN --targets Id=$INSTANCE_CANARY_ID
echo "Instancias registradas en sus TGs."

echo "--- 5. Creando el Balanceador (ALB) y Oyente (Listener) ---"
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name ALB-Canary-CLI \
  --subnets $SUBNET_IDS \
  --security-groups $SG_ALB_ID \
  --scheme internet-facing \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text) [cite: 101-106]
echo "ALB creado: $ALB_ARN"

# Oyente HTTP (Puerto 80) -> Envía 100% a Estable (Fase 1)
LISTENER_80_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP --port 80 \
  --default-actions '[{
    "Type": "forward",
    "TargetGroupArn": "'"$TG_STABLE_ARN"'"
  }]' \
  --query 'Listeners[0].ListenerArn' --output text) [cite: 107-110]
echo "Oyente HTTP:80 (100% Estable) creado."

echo "--- 6. Creando Registro DNS 'A' para el ALB ---"
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)
ALB_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "'"$APP_URL"'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'"$ALB_HOSTED_ZONE_ID"'",
          "DNSName": "'"$ALB_DNS_NAME"'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }' [cite: 140-149]
echo "Registro A (Alias) creado para $APP_URL"

# --- GUARDAR ESTADO ---
echo "Guardando IDs de recursos en $STATE_FILE..."
echo "export SG_ALB_ID=$SG_ALB_ID" > $STATE_FILE
echo "export SG_EC2_ID=$SG_EC2_ID" >> $STATE_FILE
echo "export HOSTED_ZONE_ID=$HOSTED_ZONE_ID" >> $STATE_FILE
echo "export INSTANCE_STABLE_ID=$INSTANCE_STABLE_ID" >> $STATE_FILE
echo "export INSTANCE_CANARY_ID=$INSTANCE_CANARY_ID" >> $STATE_FILE
echo "export TG_STABLE_ARN=$TG_STABLE_ARN" >> $STATE_FILE
echo "export TG_CANARY_ARN=$TG_CANARY_ARN" >> $STATE_FILE
echo "export ALB_ARN=$ALB_ARN" >> $STATE_FILE
echo "export LISTENER_80_ARN=$LISTENER_80_ARN" >> $STATE_FILE
echo "export APP_URL=$APP_URL" >> $STATE_FILE

echo "--- 🌍 ¡ACCIÓN MANUAL REQUERIDA! 🌍 ---"
echo "El despliegue está casi completo."
echo "Debes delegar tu subdominio '$DOMAIN_NAME' a AWS."
echo "Entra en NOMINALIA y crea 4 registros NS para el host 'aws' con estos valores:" [cite: 121, 123-137, 215-240]
echo $NS_SERVERS | jq -r '.[]'
echo "------------------------------------------"
echo "Una vez propagado, tu app estará en: http://$APP_URL"