# Preparación inicial en Azure

Desde PowerShell 7.4 o superior, usa Azure CLI con una cuenta que pueda crear Storage e identidades, habilitar la identidad de una VM existente y asignar roles en los recursos del laboratorio. Registra previamente Microsoft.Storage y Microsoft.ManagedIdentity si están pendientes. El grupo nuevo debe ser exclusivo de esta práctica. La VM y el almacenamiento pueden generar costes.

## Preparar almacenamiento

~~~powershell
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
az login -o none
az account set --subscription '<suscripción>'
$sub = az account show --query id -o tsv
$tenant = az account show --query tenantId -o tsv
$rg = 'rg-oidc-rbac-lab'
$region = 'northeurope'
$sa = '<nombre-global-unico>' # 3–24 letras minúsculas y dígitos
$vmGroup = '<grupo de la VM Windows>'
$vmName = '<nombre de la VM>'
az group create -n $rg -l $region -o none
az storage account create -g $rg -n $sa -l $region --sku Standard_LRS --kind StorageV2 --allow-blob-public-access false --allow-shared-key-access false --min-tls-version TLS1_2 -o none
$account = az storage account show -g $rg -n $sa --query id -o tsv
foreach ($container in 'app-config','tfstate') {
    az storage container-rm create --storage-account $account -n $container -o none
}
$app = "$account/blobServices/default/containers/app-config"
$state = "$account/blobServices/default/containers/tfstate"
~~~

El runner de GitHub y la VM deben poder alcanzar el endpoint HTTPS de Blob Storage. El endpoint es público y los contenedores requieren autenticación.

## Federación y permisos

Este ejemplo usa el sujeto inmutable de un repositorio nuevo en GitHub.com y la rama main. Si has personalizado las claims, utiliza el sujeto efectivo que corresponda a esa rama. [Referencia OIDC](https://docs.github.com/en/actions/reference/security/oidc)

~~~powershell
$identity = 'id-gh-deploy'
az identity create -g $rg -n $identity -l $region -o none
$principal = az identity show -g $rg -n $identity --query principalId -o tsv
$client = az identity show -g $rg -n $identity --query clientId -o tsv
$repo = Invoke-RestMethod 'https://api.github.com/repos/goizmo/terraform-azure-oidc-rbac-lab'
$subject = 'repo:{0}@{1}/{2}@{3}:ref:refs/heads/main' -f $repo.owner.login,$repo.owner.id,$repo.name,$repo.id
az identity federated-credential create -g $rg --identity-name $identity --name github-main --issuer 'https://token.actions.githubusercontent.com' --subject $subject --audiences 'api://AzureADTokenExchange' -o none
foreach ($scope in $app,$state) {
    az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Contributor' --scope $scope -o none
}
az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role Reader --scope $account -o none
$vmPrincipal = az vm show -g $vmGroup -n $vmName --query identity.principalId -o tsv
if (-not $vmPrincipal) {
    az vm identity assign -g $vmGroup -n $vmName -o none
    $vmPrincipal = az vm show -g $vmGroup -n $vmName --query identity.principalId -o tsv
}
az role assignment create --assignee-object-id $vmPrincipal --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Reader' --scope $app -o none
~~~

Si otro proyecto Terraform administra la VM, refleja allí la identidad de sistema. Si ya tiene identidades asignadas por el usuario, conserva esas asociaciones al habilitar la identidad de sistema en su configuración propietaria. Comprueba también los roles heredados antes de interpretar una prueba de acceso.

En **Settings → Secrets and variables → Actions → Variables** crea estas variables de repositorio con los valores de la misma sesión.

| Variable | Valor |
| --- | --- |
| AZURE_CLIENT_ID | $client |
| AZURE_TENANT_ID | $tenant |
| AZURE_SUBSCRIPTION_ID | $sub |
| STORAGE_ACCOUNT | $sa |
| APP_CONTAINER_ID | $app |

## Limpieza

Desactiva el workflow de despliegue y retira la credencial federada github-main. Revisa el inventario del grupo antes de eliminarlo. Si es exclusivo del ejercicio y ya puedes descartar configuración y estado, elimina rg-oidc-rbac-lab. Retira las cinco variables de GitHub. La VM pertenece a su grupo original. Antes de retirar su identidad, comprueba si otras aplicaciones la utilizan.
