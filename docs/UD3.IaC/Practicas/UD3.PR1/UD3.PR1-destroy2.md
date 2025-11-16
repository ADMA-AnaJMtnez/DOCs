```bash
#!/bin/bash
echo "Destruyendo infraestructura... Cuidado, esta acción es irreversible."
read -p "¿Estás seguro? (escribe 'si' para continuar): " CONFIRM

if [ "$CONFIRM" != "si" ]; then
  echo "Cancelado."
  exit 0
fi

source stack.vars

echo "--- 1. Borrando Registros DNS (Route 53) ---"
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)
ALB_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

# Borrar Registro A (Alias)
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
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
  }'
echo "Registro A (Alias) eliminado."

# Borrar CNAME de validación
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "'"$DNS_RECORD_NAME"'",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'"$DNS_RECORD_VALUE"'"}]
      }
    }]
  }'
echo "Registro CNAME de validación eliminado."

echo "--- 2. Borrando Oyentes y ALB ---"
aws elbv2 delete-listener --listener-arn $LISTENER_80_ARN
aws elbv2 delete-listener --listener-arn $LISTENER_443_ARN
echo "Oyentes HTTP y HTTPS eliminados."

aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
echo "ALB eliminado. Esperando..."
sleep 30

echo "--- 3. Borrando Grupos de Destino (TGs) ---"
aws elbv2 delete-target-group --target-group-arn $TG_STABLE_ARN
aws elbv2 delete-target-group --target-group-arn $TG_CANARY_ARN
echo "TGs eliminados."

echo "--- 4. Terminando Instancias EC2 ---"
aws ec2 terminate-instances --instance-ids $INSTANCE_STABLE_ID $INSTANCE_CANARY_ID
echo "Instancias terminadas."

echo "--- 5. Borrando Certificado (ACM) ---"
aws acm delete-certificate --certificate-arn $CERT_ARN
echo "Certificado eliminado."

echo "--- 6. Borrando Zona Alojada (Route 53) ---"
echo "¡Acción Manual! Primero debes borrar los 4 NS en Nominalia."
read -p "Pulsa [Enter] CUANDO HAYAS BORRADO los NS en Nominalia..."
aws route53 delete-hosted-zone --id $HOSTED_ZONE_ID
echo "Zona Alojada eliminada."

echo "--- 7. Borrando Grupos de Seguridad (SG) ---"
echo "Esperando 60s a que se liberen las ENIs y se terminen las instancias..."
aws ec2 wait instance-terminated --instance-ids $INSTANCE_STABLE_ID $INSTANCE_CANARY_ID
sleep 60
aws ec2 delete-security-group --group-id $SG_EC2_ID
aws ec2 delete-security-group --group-id $SG_ALB_ID
echo "SGs eliminados."

rm $STATE_FILE
echo "Limpieza completada."
```