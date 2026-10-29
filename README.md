# Pre-entrega 2 — Ingesta en tiempo real con Kinesis, Firehose y S3

## Descripción

Este proyecto extiende la infraestructura base de AWS implementada en la Pre-entrega 1 para incorporar un flujo de ingesta de datos en tiempo real. La infraestructura se administra mediante Terraform y utiliza Amazon Kinesis Data Streams para recibir eventos, Amazon Kinesis Data Firehose para entregarlos a Amazon S3 y CloudWatch para registrar la actividad y monitorear el stream.

La prueba de ingesta utiliza un productor en Python que genera eventos simulados de cotizaciones bursátiles, con fecha y hora, ticker y precio.

**Región de AWS:** `us-east-2` (Ohio).

## Arquitectura

El flujo de datos implementado es el siguiente:

```
Productor Python
       |
       v
Kinesis Data Streams
       |
       v
Kinesis Data Firehose
       |
       v
Amazon S3 — Bronze

```

CloudWatch registra logs de entrega de Firehose y monitorea las métricas de lectura y escritura de Kinesis mediante dos alarmas.

Kinesis Data Streams funciona como capa de recepción de eventos. Firehose consume los registros del stream y los entrega al bucket S3, donde se almacenan como objetos organizados en prefijos que representan el año, el mes y el día de entrega.

## Estructura del proyecto

La estructura conserva la organización de la pre-entrega anterior y agrega los recursos de ingesta:

```
.
├── modules/
│   ├── network/
│   ├── identity/
│   └── ingestion/
├── enviroments/
│   └── dev/
│       ├── .terraform.lock.hcl
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── provider.tf
│       ├── terraform.tfvars.example
│       └── variables.tf
├── producer.py
├── requirements.txt
├── .gitignore
└── README.md

```

> El directorio se llama `enviroments/dev` en este repositorio. La estructura anterior es esquemática: los archivos y módulos deben corresponder a los existentes en el repositorio.

## Requisitos previos

- Terraform instalado.
- AWS CLI instalado y configurado con credenciales que permitan administrar los recursos definidos.
- Python 3.14 instalado.
- Dependencias de Python instaladas desde `requirements.txt`.

La prueba del proyecto se realizó con **Python 3.14**.
- Acceso a la cuenta de AWS y a la región `us-east-2`.
- Bucket S3 y tabla DynamoDB previamente creados para el backend remoto de Terraform.

Las credenciales de AWS deben configurarse localmente mediante AWS CLI u otro mecanismo seguro. No deben incluirse en el código fuente ni en el repositorio.

## Configuración de variables

El repositorio incluye `terraform.tfvars.example` como plantilla de configuración. El archivo local `terraform.tfvars` está excluido de Git mediante `.gitignore`.

Desde la raíz del repositorio, abrir **PowerShell** y crear el archivo local:

```powershell
Copy-Item enviroments/dev/terraform.tfvars.example enviroments/dev/terraform.tfvars
```

> Si se utiliza Git Bash, el equivalente es `cp enviroments/dev/terraform.tfvars.example enviroments/dev/terraform.tfvars`.

El archivo de ejemplo contiene los siguientes parámetros:

- `environment`: nombre del entorno de despliegue.
- `region`: región de AWS.
- `cidr_vpc`: bloque CIDR de la VPC.
- `data_bucket_name`: nombre del bucket destinado a los datos de ingesta.
- `private_subnet_1_cidr`: bloque CIDR de la primera subred privada.
- `private_subnet_2_cidr`: bloque CIDR de la segunda subred privada.

Los valores de referencia corresponden al entorno `dev` de esta entrega. El nombre del bucket debe coincidir con el definido en la configuración de Terraform y estar disponible en la cuenta de destino.

## Inicialización y despliegue

Desde la raíz del repositorio, ejecutar:

```
cd enviroments/dev
terraform init
terraform validate
terraform plan
terraform apply
```

- `terraform init`: inicializa el directorio de trabajo, configura el backend remoto y descarga los proveedores.
- `terraform validate`: comprueba la validez de la configuración.
- `terraform plan`: muestra los cambios propuestos por Terraform.
- `terraform apply`: aplica los cambios después de solicitar confirmación.

Para consultar los identificadores de los recursos desplegados:

```
terraform output
```

## Recursos implementados

### Ingesta — Amazon Kinesis Data Streams

Se crea el stream `dev-kinesis-ingest-stream` con la siguiente configuración:

| **Característica** | **Configuración**            |
| ------------------ | ---------------------------- |
| Nombre             | `dev-kinesis-ingest-stream`  |
| Modo de capacidad  | Provisionado (`PROVISIONED`) |
| Shards             | 2                            |
| Retención          | 48 horas                     |
| Cifrado            | KMS                          |
| Región             | `us-east-2`                  |

El productor Python envía los eventos al stream mediante la operación `PutRecords`, agrupándolos en lotes de hasta 100 registros por solicitud.

Cada evento contiene los siguientes campos:

- `EVENT_TIME`: fecha y hora de generación.
- `TICKER`: símbolo bursátil seleccionado aleatoriamente.
- `PRICE`: precio simulado.

El productor utiliza claves de partición generadas mediante UUID para distribuir los registros entre las particiones del stream.

### Entrega — Amazon Kinesis Data Firehose

Se configura el stream de entrega `dev-firehose-delivery-stream`, que utiliza `dev-kinesis-ingest-stream` como origen y el bucket S3 Bronze como destino.

| **Característica**  | **Configuración**              |
| ------------------- | ------------------------------ |
| Stream de entrega   | `dev-firehose-delivery-stream` |
| Origen              | Kinesis Data Streams           |
| Destino             | Amazon S3                      |
| Buffer por tamaño   | 5 MB                           |
| Intervalo de buffer | 60 segundos                    |

Firehose agrupa los registros antes de escribirlos en S3, por lo que la entrega no es necesariamente inmediata para cada evento individual.

Los objetos se almacenan utilizando la siguiente estructura de prefijos:

```
bronze/
└── ingestion/
    └── year=YYYY/
        └── month=MM/
            └── day=DD/
                └── objeto-generado-por-firehose

```

La configuración también define un prefijo separado para los registros de entrega que presentan errores:

```
bronze/errors/

```

La partición por fecha corresponde al momento de entrega utilizado por Firehose, no necesariamente a la fecha de generación de cada evento.

### Almacenamiento — Amazon S3 Bronze

El bucket de destino es:

`entrega2-bronze-dev-2026`

Los eventos recibidos se almacenan en objetos de S3 dentro del prefijo `bronze/ingestion/`. Los objetos contienen los registros JSON entregados por Firehose.

La configuración no habilita el versionado del bucket, ya que no forma parte de los requisitos definidos para esta entrega.

### Identidad y permisos — IAM

La infraestructura utiliza roles y políticas IAM para autorizar la lectura del stream, la entrega de registros a S3 y la escritura de logs en CloudWatch.

Entre los roles expuestos por Terraform se encuentran:

- `dev-streaming-processor-role`: rol destinado al procesamiento de datos en streaming.
- `dev-audit-role`: rol destinado a tareas de auditoría.

El acceso efectivo depende de las políticas asociadas a cada rol y de las relaciones de confianza definidas en la configuración.

### Monitoreo — Amazon CloudWatch

La infraestructura incluye un grupo de logs para Firehose:

`/aws/kinesisfirehose/dev-firehose-delivery-stream`

El grupo tiene una retención configurada de 7 días y utiliza el stream de logs `S3Delivery`.

Además, se definen dos alarmas de CloudWatch para monitorear el stream de Kinesis:

| **Alarma**                              | **Métrica**                          |
| --------------------------------------- | ------------------------------------ |
| `dev-kinesis-read-throughput-exceeded`  | `ReadProvisionedThroughputExceeded`  |
| `dev-kinesis-write-throughput-exceeded` | `WriteProvisionedThroughputExceeded` |

Estas alarmas permiten detectar eventos de limitación de lectura o escritura asociados a la capacidad provisionada de Kinesis.

## Ejecución del productor

Una vez desplegada la infraestructura y configuradas las credenciales de AWS, instalar las dependencias desde el directorio que contiene `requirements.txt`:

```
pip install -r requirements.txt
```

Luego, ejecutar el productor desde el directorio donde se encuentra `producer.py`:

```
python producer.py
```

El script genera 100 eventos simulados y los envía al stream `dev-kinesis-ingest-stream`.

El productor informa la cantidad de registros aceptados por Kinesis en el primer intento y contempla reintentos para los registros que no se hayan podido enviar.

La ejecución de prueba produjo el siguiente resultado:

```
Registros procesados por Kinesis: 100/100 en el primer intento

```

Esto confirma que Kinesis aceptó los 100 registros enviados en esa ejecución.

## Verificación de la ingesta

Después de ejecutar el productor, se verificó la actividad de Firehose en AWS y la generación de un objeto en S3.

El objeto comprobado se encontraba en el siguiente prefijo:

```
s3://entrega2-bronze-dev-2026/
  bronze/ingestion/year=2026/month=10/day=29/

```

El objeto tenía un tamaño aproximado de 4 KB y contenía registros JSON con los campos `EVENT_TIME`, `TICKER` y `PRICE`.

Una muestra de su contenido fue:

```json
{"EVENT_TIME": "2026-10-29T01:38:51.631075", "TICKER": "INTC", "PRICE": 30.17}
{"EVENT_TIME": "2026-10-29T01:38:51.631083", "TICKER": "TBV", "PRICE": 19.65}
```

Los registros del objeto se observaron concatenados, sin saltos de línea entre ellos. Esto es compatible con la entrega de registros por Firehose sin un delimitador de nueva línea configurado.

La prueba permite comprobar que los registros fueron aceptados por Kinesis y que se generó un objeto en el destino S3. El resultado registrado no constituye por sí solo un conteo independiente de los 100 registros almacenados.

## Backend remoto de Terraform

Terraform utiliza un backend remoto en Amazon S3 para almacenar el estado de la infraestructura.

- **Bucket:** `data-engineering-state-bucket`.
- **Clave:** `Pre-entrega_2_ingesta_real-time_sobre_el_entorno_base/terraform.tfstate`.
- **Región:** `us-east-2`.
- **Bloqueo del estado:** tabla DynamoDB `terraform-locks`.

El bucket del backend y la tabla DynamoDB se crearon previamente, fuera de esta configuración de Terraform. El backend permite conservar el estado de los recursos administrados y coordinar las operaciones de Terraform mediante el mecanismo de bloqueo configurado.

### Reproducción en otra cuenta de AWS

La configuración original del backend apunta a recursos creados previamente en una cuenta específica. Para ejecutar el proyecto en otra cuenta, es necesario adaptar `backend.tf` para utilizar un bucket S3 y una tabla de bloqueo propios, creados previamente en la región elegida.

También se deben revisar `terraform.tfvars` y los permisos IAM, así como verificar que el nombre del bucket de destino esté disponible.

Después de modificar el backend, ejecutar `terraform init` para inicializarlo con la nueva configuración.

Las credenciales deben configurarse localmente y no deben incluirse en el repositorio.

## Outputs

La configuración expone los siguientes outputs:

| **Output**                         | **Descripción**                          |
| ---------------------------------- | ---------------------------------------- |
| `vpc_id`                           | ID de la VPC                             |
| `private_subnet_ids`               | IDs de las subredes privadas             |
| `streaming_processor_role_arn`     | ARN del rol de procesamiento             |
| `audit_role_arn`                   | ARN del rol de auditoría                 |
| `kinesis_ingest_stream_arn`        | ARN del stream de Kinesis                |
| `firehose_delivery_stream_arn`     | ARN del stream de entrega de Firehose    |
| `s3_bucket_arn`                    | ARN del bucket de destino                |
| `cloudwatch_metric_alarm_arn`      | ARN de la alarma de escritura de Kinesis |
| `cloudwatch_metric_alarm_read_arn` | ARN de la alarma de lectura de Kinesis   |

Estos outputs permiten consultar los identificadores generados por Terraform sin tener que codificarlos manualmente en otros recursos.

## Destrucción de los recursos

Para revisar qué recursos se eliminarían y, si corresponde, destruir la infraestructura administrada por Terraform:

```bash
terraform plan -destroy
terraform destroy
```

**Importante:** si se ejecutó `producer.py` y Firehose entregó registros al bucket S3 de destino, el bucket puede contener objetos que impidan su eliminación. En ese caso, antes de volver a ejecutar `terraform destroy`, es necesario eliminar el contenido del bucket desde la consola de AWS (Amazon S3), verificando previamente que los datos puedan descartarse.

La eliminación de los objetos no se realiza automáticamente con la configuración actual de Terraform. El bucket del backend remoto de Terraform y la tabla DynamoDB utilizados para el estado y el bloqueo no forman parte de los recursos administrados por esta configuración, por lo que deben conservarse para mantener el estado del proyecto.