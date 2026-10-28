# Pre-entrega 1 — Infraestructura base con Terraform y AWS

## Descripción

Este proyecto implementa una infraestructura base en AWS para el entorno de desarrollo (`dev`) mediante Terraform. La configuración está organizada en módulos para separar los recursos de red de los recursos de identidad y acceso (IAM).

**Región de AWS:** `us-east-2` (Ohio).

## Estructura del proyecto

```text
.
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── identity/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── enviroments/
│   └── dev/
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars.example
│       └── outputs.tf
├── .gitignore
├── README.md
└── PLAN_OUTPUT.md
```

> El directorio se llama `enviroments/dev` en este repositorio.

## Requisitos previos

- Terraform instalado.
- AWS CLI instalado y configurado con credenciales que permitan administrar los recursos definidos.
- Un bucket S3 existente para el estado remoto.
- Una tabla DynamoDB existente para el bloqueo del estado.
- Un bucket S3 de datos disponible en la cuenta de AWS.

En la configuración original, el backend utiliza el bucket `juan-terraform-state-2026` y la tabla DynamoDB `terraform-locks`, ambos en la región `us-east-2`. El bucket de datos configurado como ejemplo es `juan-terraform-data-2026`.

El bucket del backend y la tabla DynamoDB se crearon previamente, fuera de esta configuración de Terraform. El bucket de datos también debe existir antes de aplicar la infraestructura.

## Configuración de variables

Por buenas prácticas, el archivo local `terraform.tfvars` está excluido del repositorio mediante `.gitignore`. El repositorio incluye `terraform.tfvars.example` como plantilla de configuración.

Desde la raíz del repositorio, crear el archivo local a partir de la plantilla:

```powershell
Copy-Item enviroments/dev/terraform.tfvars.example enviroments/dev/terraform.tfvars
```

El archivo de ejemplo contiene los siguientes parámetros:

- `environment`: nombre del entorno.
- `region`: región de AWS.
- `cidr_vpc`: bloque CIDR de la VPC.
- `data_bucket_name`: nombre del bucket de datos.
- `private_subnet_1_cidr`: bloque CIDR de la primera subred privada.
- `private_subnet_2_cidr`: bloque CIDR de la segunda subred privada.

Los valores del archivo de ejemplo son de referencia y pueden necesitar ajustes según la cuenta y la infraestructura existente. El nombre del bucket de datos debe corresponder a un bucket disponible en la cuenta de destino.

## Inicialización y despliegue

Una vez configuradas las variables y las credenciales de AWS, ejecutar los siguientes comandos desde la raíz del repositorio:

```powershell
cd enviroments/dev
terraform init
terraform validate
terraform plan
terraform apply
```

- `terraform init`: inicializa el directorio de trabajo, configura el backend remoto y descarga los proveedores necesarios.
- `terraform validate`: comprueba la validez de la configuración.
- `terraform plan`: muestra los cambios que Terraform propone realizar sin modificar la infraestructura.
- `terraform apply`: aplica los cambios después de solicitar confirmación.

Para consultar los outputs generados:

```powershell
terraform output
```

## Recursos creados

### Red — módulo `network`

| Recurso | Configuración |
|---|---|
| VPC | CIDR `10.0.0.0/16`, nombre `dev-vpc` |
| Subred privada 1 | CIDR configurable; valor de ejemplo `10.0.1.0/24`, zona `us-east-2a` |
| Subred privada 2 | CIDR configurable; valor de ejemplo `10.0.2.0/24`, zona `us-east-2b` |
| Tabla de rutas | Una tabla privada compartida por ambas subredes |
| Asociaciones de rutas | Una asociación por subred |
| VPC Gateway Endpoint | Endpoint para Amazon S3 asociado a la tabla de rutas privada |

No se definen un Internet Gateway ni un NAT Gateway. El Gateway Endpoint permite dirigir el tráfico destinado a S3 a través de la red de AWS sin requerir una salida a Internet para ese tráfico. El acceso efectivo también depende de los permisos IAM y de las políticas aplicables.

### Identidad y acceso — módulo `identity`

| Recurso | Función |
|---|---|
| `dev-streaming-processor-role` | Rol de ejecución para Amazon Kinesis Data Analytics |
| `dev-streaming-processor-s3-policy` | Política de acceso a datos en S3 |
| Asociación de política S3 | Asocia la política de acceso a datos con el rol de procesamiento |
| `dev-audit-role` | Rol destinado a tareas de auditoría |
| Asociación de `ReadOnlyAccess` | Asocia la política administrada de lectura de AWS al rol de auditoría |

La política del rol de procesamiento concede los siguientes permisos sobre el bucket configurado:

- `s3:ListBucket`, limitado al prefijo `datos/streaming`.
- `s3:GetObject` y `s3:PutObject`, limitados a los objetos dentro de `datos/streaming/`.

El rol de auditoría utiliza la política administrada por AWS `ReadOnlyAccess`.

## Backend remoto

Terraform utiliza un backend remoto en Amazon S3 para almacenar el estado:

- **Bucket:** `juan-terraform-state-2026`.
- **Clave:** `Pre-entrega_1_infraestructura_base_con_entorno_de_desarrollo_e_IAM_core/terraform.tfstate`.
- **Región:** `us-east-2`.
- **Bloqueo del estado:** tabla DynamoDB `terraform-locks`.
- **Cifrado:** habilitado mediante la configuración del backend.

El estado registra los recursos administrados por Terraform y permite comparar la configuración con la infraestructura existente.

### Reproducción en otra cuenta de AWS

La configuración original del backend apunta a recursos creados previamente en una cuenta específica de AWS. Para ejecutar el proyecto en otra cuenta, se debe adaptar `backend.tf` para utilizar un bucket S3 y una tabla DynamoDB propios, creados previamente en la región elegida.

También se debe revisar `terraform.tfvars` y configurar un bucket de datos disponible en la cuenta de destino. Si se modifican la región o los rangos de red, hay que verificar que las zonas de disponibilidad y los bloques CIDR sean compatibles con la infraestructura elegida.

Después de adaptar el backend, ejecutar nuevamente `terraform init` para inicializarlo con la configuración correspondiente.

Las credenciales de AWS deben configurarse localmente mediante AWS CLI u otro mecanismo seguro. No deben incluirse en el repositorio.

## Outputs

La configuración expone los siguientes valores:

- `vpc_id`: ID de la VPC.
- `private_subnet_ids`: IDs de las dos subredes privadas.
- `streaming_processor_role_arn`: ARN del rol de procesamiento.
- `audit_role_arn`: ARN del rol de auditoría.

Estos outputs permiten consultar los identificadores generados por Terraform sin hardcodearlos en otros recursos.

## Destrucción de los recursos

Para revisar qué recursos se eliminarían y luego destruir la infraestructura administrada por Terraform:

```powershell
terraform plan -destroy
terraform destroy
```

Antes de confirmar la destrucción, revisar el plan que muestra Terraform. Estos comandos no eliminan el código del repositorio ni los recursos del backend que fueron creados fuera de esta configuración.

## Evidencia del plan

El archivo [PLAN_OUTPUT.md](PLAN_OUTPUT.md) contiene la salida del plan de Terraform correspondiente a esta preentrega, con el detalle de los recursos que se propuso crear.
