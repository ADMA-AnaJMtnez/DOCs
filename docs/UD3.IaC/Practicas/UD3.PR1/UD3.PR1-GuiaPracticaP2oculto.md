## 🔒 UD2.PR7 (Parte 2): Migración a HTTPS con CLI

### 1. Introducción

En la Parte 1, desplegamos una infraestructura funcional pero insegura. Ahora, vamos a realizar una "actualización en caliente" (hot-swap) usando la CLI para migrar todo el tráfico a **HTTPS** sin borrar nada.

Crearemos un nuevo script `migrate-to-https.sh` para añadir los recursos de seguridad, y luego actualizaremos nuestros scripts `canary.sh` y `destroy.sh` para que reflejen la nueva arquitectura segura.

### 2. Paso 1: Crear el Script de Migración (`migrate-to-https.sh`)

Este script **añadirá** los recursos que faltan: Certificado, regla de SG, Listener 443, y modificará el Listener 80.

Crea un nuevo archivo `migrate-to-https.sh`:

Puedes ver la **explicación detallada** del script o **descargarlo** directamente:

[Ver Explicación :octicons-eye-16:](UD3.PR1-migrate-to-https.md){ .md-button }
[Descargar `UD3.PR1-destroy.sh` :octicons-download-16:](UD3.PR1-migrate-to-https.sh){ .md-button }

---
### 3. Paso 2: Actualizar `canary.sh`

El script `canary.sh` original modificaba el Listener 80. Ahora, **debe modificar el Listener 443**.

Edita `canary.sh` y cambia **una sola línea**:
* Busca: `--listener-arn $LISTENER_80_ARN`
* Reemplaza por: `--listener-arn $LISTENER_443_ARN`

### 4. Paso 3: Actualizar `destroy.sh`

Nuestro script de destrucción debe ahora eliminar los nuevos recursos (Certificado, Listener 443, CNAME de validación).

Reemplaza tu `destroy.sh` por esta versión completa y segura:
Puedes ver la **explicación detallada** del script o **descargarlo** directamente:

[Ver Explicación :octicons-eye-16:](UD3.PR1-destroy2.md){ .md-button }
[Descargar `UD3.PR1-destroy2.sh` :octicons-download-16:](UD3.PR1-destroy2.sh){ .md-button }



### 7. Ejecución y Entregable (Parte 2)

1.  **Hacer Ejecutable:** Da permisos al nuevo script:
    ```bash
    chmod +x migrate-to-https.sh
    ```
2.  **Migrar:** Ejecuta el script de migración:
    ```bash
    ./migrate-to-https.sh
    ```
3.  **Probar:** Abre tu navegador y visita `http://app.aws.tudominio.com`. Deberías ser **redirigido automáticamente** a `https://app.aws.tudominio.com` y ver el candado de seguridad 🔒.
4.  **Probar `canary.sh` (Actualizado):** Ejecuta tu `canary.sh` (ya modificado) para cambiar los pesos. Comprueba que el tráfico en `https` ahora cambia entre Verde y Azul.
5.  **Destruir:** Cuando termines todo, ejecuta el `destroy.sh` actualizado para limpiar **toda** la infraestructura (HTTP y HTTPS).
6.  **Entregable Final:**
    * Sube los nuevos scripts (`migrate-to-https.sh` y los `canary.sh` y `destroy.sh` actualizados) a tu repositorio de GitHub.
    * Completa tu PDF añadiendo:
        1.  Captura de la terminal ejecutando `migrate-to-https.sh`.
        2.  Captura de pantalla de tu navegador mostrando la redirección (del `http` al `https` con el candado 🔒).
        3.  Captura de la terminal ejecutando el `canary.sh` actualizado (mostrando que modifica el Listener 443).
        4.  Captura de la terminal ejecutando el `destroy.sh` final.
        5.  Una breve reflexión: ¿Qué ventajas e inconvenientes ves en usar la CLI (IaC) frente a la consola gráfica, especialmente para una actualización como esta?

---

### 8. 📚 Referencias de la Documentación Oficial de AWS CLI

* **EC2 (Instancias, SGs):** [AWS CLI EC2 Reference](https://docs.aws.amazon.com/cli/latest/reference/ec2/index.html)
* **ELBv2 (ALB, TGs, Listeners):** [AWS CLI ELBv2 Reference](https://docs.aws.amazon.com/cli/latest/reference/elbv2/index.html)
* **Route 53 (Zonas, Registros):** [AWS CLI Route 53 Reference](https://docs.aws.amazon.com/cli/latest/reference/route53/index.html)
* **ACM (Certificados):** [AWS CLI ACM Reference](https://docs.aws.amazon.com/cli/latest/reference/acm/index.html)
