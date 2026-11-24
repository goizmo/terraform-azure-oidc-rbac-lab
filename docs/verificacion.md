# Verificar el laboratorio

Abre una PR que cambie el nivel de log de info a debug. Comprueba que **Validar** termina correctamente. Tras fusionarla, ejecuta **Desplegar configuración** en main. El único recurso de aplicación del plan debe ser azurerm_storage_blob.appsettings. Una segunda ejecución del mismo commit debe indicar **No changes**.

## Leer desde Windows

En una ventana PowerShell dedicada, dentro de la VM y con Azure CLI instalada, ejecuta estos comandos. El login usa la identidad de sistema. Esta cuenta de prueba debe tener únicamente lectura sobre app-config, incluidos los permisos heredados.

~~~powershell
$sa = '<nombre de la cuenta del laboratorio>'
az login --identity --allow-no-subscriptions -o none
if ($LASTEXITCODE) { throw 'Falló el inicio de sesión de la VM.' }
$file = Join-Path $env:TEMP ("appsettings-{0}.json" -f [guid]::NewGuid())
az storage blob download --auth-mode login --account-name $sa -c app-config -n appsettings.json --file $file --only-show-errors -o none
if ($LASTEXITCODE) { throw 'La lectura debe funcionar antes de continuar.' }
Get-Content -Raw $file | ConvertFrom-Json | Select-Object application,logLevel,pollIntervalSeconds
~~~

El valor de logLevel debe coincidir con el commit desplegado. Desde esa misma sesión comprueba los dos límites de acceso.

~~~powershell
$probe = "rbac-probe-$([guid]::NewGuid()).json"
az storage blob upload --auth-mode login --account-name $sa -c app-config -n $probe --file $file --overwrite false --only-show-errors -o none
if ($LASTEXITCODE -eq 0) { throw "La VM pudo escribir $probe. Revisa los roles y retira el blob de prueba con una cuenta autorizada." }
az storage blob show --auth-mode login --account-name $sa -c tfstate -n lab.tfstate --query name -o tsv
if ($LASTEXITCODE -eq 0) { throw 'La VM pudo consultar el estado. Revisa los roles.' }
~~~

Ambos intentos deben devolver un 403 de autorización de datos, por ejemplo AuthorizationPermissionMismatch. Un 404, un timeout o un fallo de login requiere diagnóstico antes de aceptar el resultado. La segunda prueba consulta los metadatos del estado para evitar mostrar su contenido. Si acabas de asignar roles, deja tiempo para que se propaguen.

Guarda como evidencia el commit, enlaces a las ejecuciones, el valor leído desde Windows y los dos códigos de error. Estos resultados son criterios de aceptación para la prueba real en Azure.
