# Cloud Design Patterns

## Introduccion

Este documento describe los patrones cloud aplicados en el ecosistema app-repo + ops-repo.
Se enfoca en implementaciones que son visibles en Kubernetes y verificables en ejecucion.

## Patron 1 - Publisher Subscriber

### Problema que resuelve

Si vote dependiera de una llamada directa al worker para persistir votos, tendriamos acoplamiento fuerte.
Una caida o lentitud del worker impactaria de inmediato la experiencia del usuario en vote.

### Solucion aplicada

Kafka desacopla produccion y consumo de mensajes:

- vote publica eventos en el topic votes.
- worker consume eventos en forma asincrona.
- result consulta datos persistidos en PostgreSQL.

Flujo simplificado:

Usuario -> vote -> Kafka(votes) -> worker -> PostgreSQL -> result

### Evidencia en este repositorio

- Chart de infraestructura: infrastructure/k8s
- Dependencias Kafka y PostgreSQL: infrastructure/k8s/templates
- Provisionamiento y despliegue automatizado: .github/workflows/infra.yml

### Beneficios

- Desacoplamiento entre servicios.
- Mayor resiliencia frente a caidas temporales del consumidor.
- Capacidad de absorber picos de trafico por cola.

## Patron 2 - Competing Consumers

### Problema que resuelve

Con una sola replica de worker, el procesamiento de votos puede saturarse ante picos.

### Solucion aplicada

Multiples replicas de worker consumen el mismo topic mediante consumer group,
permitiendo paralelismo y reparto de particiones.

### Evidencia en este repositorio

- Helm chart del servicio worker: worker/chart
- Despliegue por helm upgrade en ops.yml hacia el entorno objetivo.

Nota: para paralelismo efectivo, el topic debe tener suficientes particiones.

### Beneficios

- Escalado horizontal del procesamiento.
- Menor latencia de drenaje de cola.
- Mejor throughput bajo carga.

## Patron 3 - Bulkhead

### Problema que resuelve

Sin aislamiento por entorno, errores en staging pueden degradar production.

### Solucion aplicada

Se separan despliegues por namespace de Kubernetes:

- staging
- production

El workflow ops.yml selecciona namespace segun el payload entrante y aplica helm upgrade en el entorno correcto.

### Evidencia en este repositorio

- Seleccion de entorno en .github/workflows/ops.yml
- Despliegue con namespace en .github/workflows/infra.yml y .github/workflows/ops.yml

### Beneficios

- Aislamiento operativo entre validacion y produccion.
- Menor riesgo de impacto cruzado.
- Promocion controlada entre ambientes.

## Resumen

| Patron | Categoria | Implementacion principal |
|---|---|---|
| Publisher Subscriber | Mensajeria | Kafka entre vote y worker |
| Competing Consumers | Escalabilidad | Multiples workers consumiendo en paralelo |
| Bulkhead | Resiliencia | Namespaces staging y production |
