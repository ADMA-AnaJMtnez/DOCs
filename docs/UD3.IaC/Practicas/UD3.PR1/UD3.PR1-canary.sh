#!/bin/bash

# Cargar los IDs de los recursos
source stack.vars

echo "Selecciona la fase del despliegue Canary:"
echo " 1) Fase 2: 90% Estable / 10% Canary"
echo " 2) Fase 3: 0% Estable / 100% Canary"
echo " 3) Fase 1: 100% Estable (Rollback)"
read -p "Elige una opción (1, 2, o 3): " FASE

if [ "$FASE" == "1" ]; then
  echo "Activando Fase 2: 90% Estable / 10% Canary..."
  WEIGHTS_JSON='[
    {"TargetGroupArn": "'"$TG_STABLE_ARN"'", "Weight": 90},
    {"TargetGroupArn": "'"$TG_CANARY_ARN"'", "Weight": 10}
  ]'
elif [ "$FASE" == "2" ]; then
  echo "Activando Fase 3: 0% Estable / 100% Canary..."
  WEIGHTS_JSON='[
    {"TargetGroupArn": "'"$TG_STABLE_ARN"'", "Weight": 0},
    {"TargetGroupArn": "'"$TG_CANARY_ARN"'", "Weight": 100}
  ]'
elif [ "$FASE" == "3" ]; then
  echo "Activando Fase 1: 100% Estable (Rollback)..."
  WEIGHTS_JSON='[
    {"TargetGroupArn": "'"$TG_STABLE_ARN"'", "Weight": 100},
    {"TargetGroupArn": "'"$TG_CANARY_ARN"'", "Weight": 0}
  ]'
else
  echo "Opción no válida."
  exit 1
fi

# Modificamos el listener HTTP (80)
aws elbv2 modify-listener \
  --listener-arn $LISTENER_80_ARN \
  --default-actions '[{
    "Type": "forward",
    "ForwardConfig": {
      "TargetGroups": '"$WEIGHTS_JSON"'
    }
  }]'
  
echo "¡Pesos del balanceador actualizados!"