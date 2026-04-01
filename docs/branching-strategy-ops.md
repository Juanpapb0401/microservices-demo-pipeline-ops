# Branching Strategy

## Estrategia de branching para operaciones - Trunk-Based Development

### Repositorio: `ops-repo`

Contiene archivos de Terraform para provisionar AKS, Helm charts de infraestructura
compartida (Kafka, PostgreSQL) y workflows de despliegue. Su responsabilidad
comienza cuando recibe el trigger del app-repo.

### Por que Trunk-Based y no GitFlow

El ops-repo no contiene features de negocio. Contiene definiciones que evolucionan
y que todo el equipo necesita de forma inmediata. Ejemplos concretos:

- La version de Maven usada en pipeline cambia de 3.8 a 3.9.
- La imagen base de Docker pasa de node:18 a node:22.
- El chart de Kafka se actualiza de 17.x a 25.x.
- Se ajusta el tamano del node pool en Terraform.

Cuando uno de estos cambios ocurre, todos los desarrolladores necesitan jalarlo de
inmediato. Si la version de Maven en el pipeline no coincide con la que el equipo usa
localmente, los builds fallan para todos. No tiene sentido tener ese cambio bloqueado en
una rama feature esperando review por dias.

Trunk-Based resuelve esto: las ramas viven maximo 1-2 dias, el merge al trunk es rapido,
y el pipeline propaga la definición actualizada a todos de inmediato.

### Estructura de ramas

```
main (trunk)
  │
  ├── update/maven-3.9        ← vida máxima: 2 días
  ├── update/helm-kafka-25    ← vida máxima: 2 días
  └── fix/terraform-aks-pool  ← vida máxima: 1 día
```

Solo existe una rama permanente: main. Las ramas de trabajo son siempre cortas y
se eliminan al hacer merge.

### Naming de ramas en ops-repo

| Patrón | Cuándo usarlo |
|---|---|
| update/<componente>-<version> | Actualizacion de version de herramienta o dependencia |
| fix/<descripcion> | Correccion en configuracion de Terraform o Helm |
| add/<descripcion> | Nuevo recurso de infraestructura |

### Reglas de Trunk-Based en este proyecto

1. Ninguna rama debe vivir mas de 2 dias. Si el cambio es grande, dividir en cambios pequenos.
2. Cada merge a main puede disparar el pipeline de infraestructura si los archivos relevantes cambiaron.
3. No hay ramas dedicadas por entorno en ops-repo.
4. Los PR son obligatorios, incluso para ramas cortas.

### Cómo el ops-repo distingue staging de production

El ops-repo no usa ramas para distinguir ambientes. El ambiente destino llega como
parametro del evento disparado por app-repo:

```
app-repo push a develop -> trigger ops-repo (tag=sha-abc123, environment=staging)
app-repo push a main    -> trigger ops-repo (tag=sha-def456, environment=production)
```

El pipeline de ops recibe el tag de imagen y el ambiente, y ejecuta el Helm upgrade
correspondiente. Esto mantiene Trunk-Based puro en ops — la única fuente de verdad
sobre que esta desplegado es el pipeline, no una rama.

### Comportamiento del pipeline de infraestructura

| Disparador | Condición | Resultado |
|---|---|---|
| Trigger desde app-repo | `environment=staging` | Helm upgrade microservicios → namespace staging |
| Trigger desde app-repo | `environment=production` | Helm upgrade microservicios → namespace production |
| Push a main en ops-repo | Archivos infrastructure/** cambiaron | Helm upgrade Kafka + PostgreSQL |
| Push a main en ops-repo | Archivos terraform/** cambiaron | Terraform plan + apply |
| workflow_dispatch | Parametro environment seleccionado | Deploy manual al ambiente indicado |

### Separación de responsabilidades entre repos

```
ops-repo (Trunk-Based — CD)
├── terraform/              ← provisiona el clúster AKS en Azure
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── infrastructure/         ← despliega Kafka y PostgreSQL dentro del clúster
    ├── Chart.yaml
    └── values.yaml

app-repo (GitFlow — CI)
├── vote/                   ← microservicio Java
├── result/                 ← microservicio Node.js
├── worker/                 ← microservicio Go
└── .github/workflows/
    └── app.yml             ← build, test, push ACR, trigger ops-repo
```

---

## Flujo completo integrado

```
Developer abre PR desde feature/X hacia develop
       │
       ▼
GitHub Actions (app-repo): tests automaticos por servicio
       │
       ▼
Merge a develop aprobado
       │
       ▼
GitHub Actions (app-repo):
       - Build de imagen Docker del servicio modificado
       - Push a ACR con tag inmutable sha-commit
  - Trigger ops-repo (tag=sha-<commit>, environment=staging)
       │
       ▼
GitHub Actions (ops-repo):
  - Recibe tag + environment
       - helm upgrade del servicio con imagen y tag recibidos
  - Namespace: staging
       │
       ▼
Validación en staging por el equipo
       │
       ▼
PR de develop a main aprobado (cierre de sprint)
       │
       ▼
GitHub Actions (app-repo):
       - Build de imagen Docker del servicio modificado
       - Push a ACR con tag inmutable sha-commit
  - Trigger ops-repo (tag=sha-<commit>, environment=production)
       │
       ▼
GitHub Actions (ops-repo):
  - Recibe tag + environment
       - helm upgrade del servicio con imagen y tag recibidos
  - Namespace: production
```

---

## Resumen comparativo

| Aspecto | app-repo (GitFlow) | ops-repo (Trunk-Based) |
|---|---|---|
| Rol en CI/CD | CI - build y publicacion | CD - despliegue |
| Ramas permanentes | main, develop | Solo main |
| Ramas de trabajo | feature/*, hotfix/* | update/*, fix/*, add/* |
| Vida de una rama | Dias a semanas | Maximo 2 dias |
| PR requerido | Sí, siempre | Sí, siempre |
| Tests automaticos | Si, por servicio | Validaciones de despliegue |
| Como distingue ambientes | Por rama (develop/main) | Por parametro del trigger entrante |
| Registry de imagenes | ACR con tags inmutables | Consume tags del app-repo |
| Relacion con Scrum | Features por sprint | Cambios tecnicos por sprint |
