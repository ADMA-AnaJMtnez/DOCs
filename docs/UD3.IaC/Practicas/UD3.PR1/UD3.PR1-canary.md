* **`canary.sh`**:
    ```bash
    #!/bin/bash
    
    # Cargar los IDs de los recursos
    source stack.vars
    
    echo "Selecciona la fase del despliegue Canary:"
    [cite_start]echo " 1) Fase 2: 90% Estable / 10% Canary" [cite: 157, 163-166]
    [cite_start]echo " 2) Fase 3: 0% Estable / 100% Canary" [cite: 170, 175-176]
    echo " 3) Fase 1: 100% Estable (Rollback)"
    read -p "Elige una opción (1, 2, o 3): " FASE
    
    if [ "$FASE" == "1" ]; then
      [cite_start]echo "Activando Fase 2: 90% Estable / 10% Canary..." [cite: 163-166]
      WEIGHTS_JSON='[
        {"TargetGroupArn": "'"$TG_STABLE_ARN"'", "Weight": 90},
        {"TargetGroupArn": "'"$TG_CANARY_ARN"'", "Weight": 10}
      ]'
    elif [ "$FASE" == "2" ]; then
      [cite_start]echo "Activando Fase 3: 0% Estable / 100% Canary..." [cite: 175-176]
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
      [cite_start]}]' [cite: 159-162]
      
    echo "¡Pesos del balanceador actualizados!"
    ```