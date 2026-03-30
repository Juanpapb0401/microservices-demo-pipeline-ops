## 2. Estrategia de branching para operaciones — Trunk-Based Development

### Repositorio: `ops-repo`

Contiene los archivos de Terraform para provisionar el clúster AKS, los Helm charts de
infraestructura compartida (Kafka, PostgreSQL) y el pipeline de despliegue. Su
responsabilidad comienza cuando recibe el trigger del app-repo — **el deploy es
responsabilidad exclusiva de este repo**.

### Por qué Trunk-Based y no GitFlow

El ops-repo no contiene features de negocio — contiene **definiciones que evolucionan**
y que todo el equipo necesita de forma inmediata. Ejemplos concretos:

- La versión de Maven usada para compilar en el pipeline cambia de `3.8` a `3.9`
- La imagen base de Docker pasa de `node:18` a `node:22`
- El Helm chart de Kafka se actualiza de la versión `17.x` a `25.x`
- Se ajusta el tamaño del node pool en Terraform

Cuando uno de estos cambios ocurre, todos los desarrolladores necesitan jalarlo de
inmediato. Si la versión de Maven en el pipeline no coincide con la que el equipo usa
localmente, los builds fallan para todos. No tiene sentido tener ese cambio bloqueado en
una rama `feature/` esperando review por días.

Trunk-Based resuelve esto: las ramas viven máximo 1-2 días, el merge al trunk es rápido,
y el pipeline propaga la definición actualizada a todos de inmediato.

### Estructura de ramas

```
main (trunk)
  │
  ├── update/maven-3.9        ← vida máxima: 2 días
  ├── update/helm-kafka-25    ← vida máxima: 2 días
  └── fix/terraform-aks-pool  ← vida máxima: 1 día
```

Solo existe **una rama permanente**: `main`. Las ramas de trabajo son siempre cortas y
se eliminan al hacer merge.

### Naming de ramas en ops-repo

| Patrón | Cuándo usarlo |
|---|---|
| `update/<componente>-<version>` | Actualización de versión de herramienta o dependencia |
| `fix/<descripción>` | Corrección en configuración de Terraform o Helm |
| `add/<descripción>` | Nuevo recurso de infraestructura |

### Reglas de Trunk-Based en este proyecto

1. **Ninguna rama puede vivir más de 2 días.** Si el cambio es demasiado grande, se divide en cambios más pequeños.
2. **Cada merge al trunk puede disparar el pipeline de infraestructura** automáticamente si los archivos relevantes cambiaron.
3. **No hay ramas `develop` ni `staging`.** El ambiente destino lo determina el evento entrante, no la rama.
4. **Los PRs son obligatorios** aunque la rama sea corta — al menos una aprobación antes de mergear al trunk.

### Cómo el ops-repo distingue staging de production

El ops-repo no usa ramas para distinguir ambientes. El ambiente destino llega como
parámetro del evento que dispara el app-repo:

```
app-repo push a develop → trigger ops-repo (tag=sha-abc123, environment=staging)
app-repo push a main    → trigger ops-repo (tag=sha-def456, environment=production)
```

El pipeline de ops recibe el tag de imagen y el ambiente, y ejecuta el Helm upgrade
correspondiente. Esto mantiene Trunk-Based puro en ops — la única fuente de verdad
sobre qué está desplegado es el pipeline, no una rama.

### Comportamiento del pipeline de infraestructura

| Disparador | Condición | Resultado |
|---|---|---|
| Trigger desde app-repo | `environment=staging` | Helm upgrade microservicios → namespace staging |
| Trigger desde app-repo | `environment=production` | Helm upgrade microservicios → namespace production |
| Push a `main` en ops-repo | Archivos `infrastructure/**` cambiaron | Helm upgrade Kafka + PostgreSQL |
| Push a `main` en ops-repo | Archivos `terraform/**` cambiaron | Terraform plan + apply |
| `workflow_dispatch` | Parámetro `environment` seleccionado | Deploy manual al ambiente indicado |

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
GitHub Actions (app-repo): tests automáticos por servicio
       │
       ▼
Merge a develop aprobado
       │
       ▼
GitHub Actions (app-repo):
  - Build imagen Docker del servicio modificado
  - Push a ACR con tag sha-<commit>
  - Trigger ops-repo (tag=sha-<commit>, environment=staging)
       │
       ▼
GitHub Actions (ops-repo):
  - Recibe tag + environment
  - helm upgrade <servicio> --set image=<ACR>/<servicio>:sha-<commit>
  - Namespace: staging
       │
       ▼
Validación en staging por el equipo
       │
       ▼
PR de develop → main aprobado (cierre de sprint)
       │
       ▼
GitHub Actions (app-repo):
  - Build imagen Docker del servicio modificado
  - Push a ACR con tag sha-<commit>
  - Trigger ops-repo (tag=sha-<commit>, environment=production)
       │
       ▼
GitHub Actions (ops-repo):
  - Recibe tag + environment
  - helm upgrade <servicio> --set image=<ACR>/<servicio>:sha-<commit>
  - Namespace: production
```

---

## Resumen comparativo

| Aspecto | app-repo (GitFlow) | ops-repo (Trunk-Based) |
|---|---|---|
| Rol en CI/CD | CI — build y publicación | CD — despliegue |
| Ramas permanentes | `main`, `develop` | Solo `main` |
| Ramas de trabajo | `feature/*`, `hotfix/*` | `update/*`, `fix/*`, `add/*` |
| Vida de una rama | Días a semanas | Máximo 2 días |
| PR requerido | Sí, siempre | Sí, siempre |
| Tests automáticos | Sí, por servicio | Terraform plan (validación) |
| Cómo distingue ambientes | Por rama (`develop`/`main`) | Por parámetro del trigger entrante |
| Registry de imágenes | ACR — tags inmutables `sha-<commit>` | Consume tags del app-repo |
| Relación con Scrum | Features = user stories del sprint | Actualizaciones = tareas técnicas del sprint |
