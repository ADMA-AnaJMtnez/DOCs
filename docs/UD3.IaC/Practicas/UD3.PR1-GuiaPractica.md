## 🚀 UD2.PR7 (Parte 1): De la Consola a la CLI: Tu Despliegue Canary (HTTP)

### 1. Introducción

En la práctica UD2.PR6, construimos manualmente una arquitectura "Canary" usando la consola de AWS. Este método fue excelente para aprender visualmente, pero es lento, propenso a errores humanos y no es escalable.

El siguiente nivel profesional es la **Infraestructura como Código (IaC)**.

En esta práctica, vamos a abandonar la consola gráfica. Recrearemos **toda** la infraestructura de la UD2.PR6 (SGs, EC2, TGs, ALB, Route 53) usando exclusivamente la **AWS CLI (Command Line Interface)**. Dejaremos la aplicación funcionando de forma insegura por **HTTP (puerto 80)**.

!!! info "Parte 2"
    En la siguiente guía (Parte 2), usaremos la CLI para "parchear" esta infraestructura y migrarla a HTTPS.

### 2. Prerrequisitos

Antes de empezar, asegúrate de tener todo tu entorno local preparado:

1.  **AWS CLI Instalada:** Verifica que tienes la CLI de AWS instalada y funcional.
    * *Documentación Oficial:* [Instalación de la AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
2.  **Visual Studio Code (VS Code):** Nuestro editor de código.
    * *Documentación Oficial:* [Instalación de VS Code](https://code.visualstudio.com/download)
3.  **Git:** Para el control de versiones de nuestro código de infraestructura.
    * *Documentación Oficial:* [Instalación de Git](https://git-scm.com/downloads)
    * *Guía Relacionada:* [Cómo crear un repositorio en GitHub](https://docs.github.com/es/repositories/creating-and-managing-repositories/creating-a-new-repository)
4.  **Tu Dominio (Nominalia):** Necesitas acceso a tu registrador de dominio para el paso manual de delegación de NS.

!!! note "Usuario de AWS (Landing Zone / Academy)"
    * **Opción A (Preferida - Landing Zone):** Intentarás la práctica primero con las **credenciales programáticas** (`Access Key ID` y `Secret Access Key`) asociadas a tu usuario de la Landing Zone.
    * **Opción B (Contingencia - Academy):** Si encuentras **errores de permisos** (errores "Access Denied" o similares) en la Landing Zone, detente. **Recoge y documenta todos los errores**. Deberás **escalar estos errores** al equipo de administración.
    * Para poder completar la práctica, cambia a tu entorno de **Laboratorio de AWS Academy**, donde sí tienes los permisos de administrador necesarios.

---

### 3. Paso 1: Configuración del Entorno de Proyecto

1.  **Crear un Repositorio Privado:** Ve a GitHub y crea un nuevo repositorio **privado** llamado `iac-aws-canary-http.[TUSSIGLAS]` (reemplaza `[TUSSIGLAS]` con tus siglas).
2.  **Clonar y Abrir:** Clona el repositorio, entra en la carpeta (`cd iac-aws-canary-http.[TUSSIGLAS]`) y ábrela con VS Code (`code .`).
### 3. Paso 1: Configuración del Entorno de Proyecto

1.  **Crear un Repositorio Privado:** Ve a GitHub y crea un nuevo repositorio **privado** llamado `iac-aws-canary-http.[TUSSIGLAS]` (reemplaza `[TUSSIGLAS]` con tus siglas).
2.  **Clonar y Abrir:** Clona el repositorio, entra en la carpeta (`cd iac-aws-canary-http.[TUSSIGLAS]`) y ábrela con VS Code (`code .`).
3.  **Crear Estructura:** Crea los siguientes archivos:

    ```text
    iac-aws-canary-http.[TUSSIGLAS]/
    ├── deploy.sh
    ├── canary.sh
    ├── destroy.sh
    ├── user-data-stable.sh
    └── user-data-canary.sh
    ```

---

### 4. Paso 2: Configurar Credenciales de AWS

1.  Abre tu terminal y ejecuta `aws configure`.
2.  Introduce el `AWS Access Key ID` y `AWS Secret Access Key`.
3.  Define tu región por defecto (ej. `eu-west-1`) y formato de salida (`json`).

---

### 5. Paso 3: Escribir los Scripts de Infraestructura

#### 5.1. Scripts User Data (v1 y v2)

Copia el contenido de los scripts `bash` en los archivos correspondientes.

=== "user-data-stable.sh (v1 - Verde)"
    ```bash title="user-data-stable.sh"
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<body style='background-color:lightgreen;...'><h1>☑ Entorno ESTABLE (v1.0)...</h1>..." > /var/www/html/index.html
    ```
=== "user-data-canary.sh (v2 - Azul)"
    ```bash title="user-data-canary.sh"
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<body style='background-color:powderblue;...'><h1>🚀 Entorno CANARY (v2.0)...</h1>..." > /var/www/html/index.html
    ```

#### 5.2. El Script de Creación (`deploy.sh`)

Este script creará **todo** para HTTP: SGs (solo puerto 80), la zona DNS, las instancias, los TGs, el ALB y el Listener HTTP.

```bash title="deploy.sh"
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
aws ec2 authorize-security-group-ingress --group-id $SG_ALB_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "SG del ALB creado: $SG_ALB_ID"

SG_EC2_ID=$(aws ec2 create-security-group \
  --group-name SG-Servidores-Privado-CLI \
  --description "SG para EC2 - CLI" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
# Reglas para las Instancias (SSH desde mi IP, HTTP solo desde el ALB)
aws ec2 authorize-security-group-ingress --group-id $SG_EC2_ID --protocol tcp --port 22 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_EC2_ID --protocol tcp --port 80 --source-group $SG_ALB_ID
echo "SG de Instancias creado: $SG_EC2_ID"

echo "--- 2. Creando Zona Alojada (Route 53) ---"
ZONE_ID_OUTPUT=$(aws route53 create-hosted-zone --name $DOMAIN_NAME --caller-reference $(date +%s))
HOSTED_ZONE_ID=$(echo $ZONE_ID_OUTPUT | jq -r '.HostedZone.Id' | cut -d'/' -f3)
NS_SERVERS=$(echo $ZONE_ID_OUTPUT | jq -r '.DelegationSet.NameServers | @json')
echo "Zona Alojada Creada: $HOSTED_ZONE_ID"

echo "--- 3. Creando Instancias EC2 (Estable y Canary) ---"
INSTANCE_STABLE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_EC2_ID \
  --user-data file://user-data-stable.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Servidor-Estable-CLI}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "Instancia Estable creada: $INSTANCE_STABLE_ID"

INSTANCE_CANARY_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_EC2_ID \
  --user-data file://user-data-canary.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Servidor-Canary-CLI}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "Instancia Canary creada: $INSTANCE_CANARY_ID"

echo "--- 4. Creando Grupos de Destino (Target Groups) ---"
TG_STABLE_ARN=$(aws elbv2 create-target-group \
  --name TG-Estable-CLI \
  --protocol HTTP --port 80 \
  --vpc-id $VPC_ID \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
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
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "ALB creado: $ALB_ARN"

# Oyente HTTP (Puerto 80) -> Envía 100% a Estable (Fase 1)
LISTENER_80_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP --port 80 \
  --default-actions '[{
    "Type": "forward",
    "TargetGroupArn": "'"$TG_STABLE_ARN"'"
  }]' \
  --query 'Listeners[0].ListenerArn' --output text)
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
  }'
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