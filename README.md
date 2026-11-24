# Publicar configuración en Azure con Terraform y OIDC

Una VM Windows lee un archivo de configuración privado. GitHub Actions lo publica mediante Terraform y una identidad federada con Microsoft Entra ID. En Windows se utiliza la identidad administrada de sistema de la VM. El laboratorio permite probar ambos permisos cambiando un valor y observando qué operaciones autoriza Azure.

| Identidad | Rol | Ámbito | Operación |
| --- | --- | --- | --- |
| GitHub Actions | Storage Blob Data Contributor | Contenedor app-config | Gestionar appsettings.json |
| GitHub Actions | Storage Blob Data Contributor | Contenedor tfstate | Leer, bloquear y actualizar el estado |
| GitHub Actions | Reader | Cuenta de almacenamiento | Consultar metadatos desde el proveedor AzureRM |
| VM Windows | Storage Blob Data Reader | Contenedor app-config | Leer la configuración |

Los roles de escritura también permiten borrar blobs en sus respectivos contenedores. El operador crea las asignaciones de rol y la relación de confianza una sola vez. El pipeline dispone únicamente de los tres permisos indicados para su identidad.

## Recorrido del laboratorio

1. Prepara la cuenta de almacenamiento, los dos contenedores y las identidades con la [guía de preparación](bootstrap/README.md). Configura las cinco variables de Actions.
2. Cambia el campo **logLevel** de info a debug en [appsettings.json](config/appsettings.json) mediante una pull request. [Validar](.github/workflows/validate.yml) comprueba JSON, formato y esquema Terraform antes de fusionar.
3. En **Actions → Desplegar configuración → Run workflow**, selecciona main. [El workflow de despliegue](.github/workflows/deploy.yml) obtiene acceso temporal mediante OIDC y aplica el plan que acaba de generar en el mismo runner.
4. Lee el nuevo valor desde la VM y verifica que Azure rechaza la escritura y la lectura del estado. Repite el despliegue para comprobar la idempotencia. [Guía de verificación](docs/verificacion.md)

## Decisiones técnicas

- La cuenta utiliza HTTPS, contenedores privados y autenticación de datos mediante Entra. El runner y la VM necesitan conectividad con el endpoint público de Blob Storage.
- El backend guarda el estado en un contenedor independiente. Terraform conserva en el estado el contenido del archivo que publica. El JSON contiene solo datos de ejemplo.
- El proveedor puede reemplazar el blob cuando cambia su contenido. Durante ese reemplazo puede haber una interrupción breve en la lectura.
- Las PR tienen acceso de lectura al repositorio. El único job que solicita un token OIDC es el de despliegue manual desde main. En un equipo, protege esa rama y exige revisión de los cambios en los workflows.

[Configuración Terraform](infra/main.tf) · [Backend AzureRM](https://developer.hashicorp.com/terraform/language/backend/azurerm) · [OIDC en GitHub Actions](https://docs.github.com/en/actions/reference/security/oidc)
