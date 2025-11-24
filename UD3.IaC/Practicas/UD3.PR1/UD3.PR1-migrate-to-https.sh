#!/bin/bash
echo "🔒 Iniciando migración a HTTPS..."

# Cargar los IDs de los recursos existentes
source stack.vars

echo "--- 1. Solicitando Certificado SSL (ACM) ---"
CERT_ARN=$(aws acm request-certificate \
  --domain-name "*.${DOMAIN_NAME}" \
  --validation-method DNS \
  --query 'CertificateArn' --output text)
echo "Certificado solicitado: $CERT_ARN"
echo "⏳ Esperando 10s para que ACM genere los datos de validación..."
sleep 10

# Obtener el CNAME de validación
DNS_RECORD_NAME=$(aws acm describe-certificate --certificate-arn $CERT_ARN --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' --output text)
DNS_RECORD_VALUE=$(aws acm describe-certificate --certificate-arn $CERT_ARN --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' --output text)

echo "--- 2. Creando Registro CNAME de validación en Route 53 ---"
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "'"$DNS_RECORD_NAME"'",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'"$DNS_RECORD_VALUE"'"}]
      }
    }]
  }'
echo "Registro CNAME creado."

echo "--- 3. Actualizando SG del ALB (Añadiendo Puerto 443) ---"
aws ec2 authorize-security-group-ingress --group-id $SG_ALB_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
echo "Regla HTTPS:443 añadida a $SG_ALB_ID"

echo "--- 4. Creando el Nuevo Oyente (Listener) HTTPS ---"
echo "⏳ Esperando validación del certificado (puede tardar)..."
aws acm wait certificate-validated --certificate-arn $CERT_ARN
echo "¡Certificado validado!"

# Obtenemos la configuración actual del Listener 80 para replicarla
CURRENT_ACTIONS=$(aws elbv2 describe-listeners --listener-arns $LISTENER_80_ARN --query 'Listeners[0].DefaultActions' --output json)

# Creamos el Listener 443 con la MISMA configuración que tiene ahora el 80
LISTENER_443_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions "$CURRENT_ACTIONS" \
  --query 'Listeners[0].ListenerArn' --output text)
echo "Oyente HTTPS:443 creado: $LISTENER_443_ARN"

echo "--- 5. Modificando el Oyente (Listener) HTTP para Redirigir ---"
aws elbv2 modify-listener \
  --listener-arn $LISTENER_80_ARN \
  --default-actions '[{
    "Type": "redirect",
    "RedirectConfig": {
      "Protocol": "HTTPS",
      "Port": "443",
      "StatusCode": "HTTP_301"
    }
  }]'
echo "Oyente HTTP:80 modificado para redirigir a HTTPS."

# --- GUARDAR NUEVO ESTADO ---
echo "export CERT_ARN=$CERT_ARN" >> $STATE_FILE
echo "export LISTENER_443_ARN=$LISTENER_443_ARN" >> $STATE_FILE
echo "export DNS_RECORD_NAME=$DNS_RECORD_NAME" >> $STATE_FILE
echo "export DNS_RECORD_VALUE=$DNS_RECORD_VALUE" >> $STATE_FILE

echo "✅ Migración a HTTPS completada."