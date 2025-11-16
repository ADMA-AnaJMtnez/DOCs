# Configurar Credenciales

### Gestión de Credenciales en el AWS Toolkit (para VS Code)

**Enlace:** [https://docs.aws.amazon.com/toolkit-for-visual-studio-code/latest/userguide/credentials.html](https://docs.aws.amazon.com/toolkit-for-visual-studio-code/latest/userguide/credentials.html)

!!! info "Por qué es útil"
    Esta es la documentación específica para la extensión de AWS en VS Code. Explica todos los métodos que la extensión utiliza para encontrar tus credenciales, dándole prioridad al archivo credentials que te mencioné (el método manual).

---

### Configuración y Archivos de Credenciales (AWS CLI)

**Enlace:** [https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

!!! note "Por qué es útil"
    Este es el documento más importante para la configuración manual. Detalla la ubicación exacta de las carpetas (`~/.aws`), los nombres de los archivos (`credentials` y `config`), la sintaxis exacta que debes usar (ej. `[default]`), y cómo gestionar múltiples perfiles.

---

### Gestión de Claves de Acceso (AWS IAM)

**Enlace:** [https://docs.aws.amazon.com/IAM/latest/UserGuide/managing-user-access-keys.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/managing-user-access-keys.html)

!!! tip "Por qué es útil"
    Este enlace explica la "Fase 1" de mi respuesta anterior: cómo iniciar sesión en la consola de AWS y crear el par de claves (Access Key ID y Secret Access Key) para un usuario IAM. Sigue las mejores prácticas que se mencionan aquí.

---

### Página del Marketplace de AWS Toolkit para VS Code

**Enlace:** [https://marketplace.visualstudio.com/items?itemName=AmazonWebServices.aws-toolkit-vscode](https://marketplace.visualstudio.com/items?itemName=AmazonWebServices.aws-toolkit-vscode)

!!! info "Por qué es útil"
    Esta es la página oficial de la extensión. Es un buen punto de partida y a menudo contiene enlaces rápidos a la documentación principal y guías de inicio (Setup).

---

> Estos recursos son la base sobre la que funcionan todas las herramientas de AWS. El enlace número 2 (sobre los archivos cli-configure-files) es la referencia técnica principal para el método manual.