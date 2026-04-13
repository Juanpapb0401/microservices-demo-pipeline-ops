# Cloud Design Patterns

## Introduccion

Este documento describe los patrones cloud aplicados en el ecosistema app-repo + ops-repo.
Se enfoca en implementaciones visibles en Kubernetes y verificables en ejecucion.
En esta version del ops-repo se documentan solo los patrones operativos usados para despliegue,
aislamiento y resiliencia.

## Patron 1 - Competing Consumers

### Problema que resuelve

Con una sola replica de worker, el procesamiento de votos puede saturarse ante picos.

### Solucion aplicada

Multiples replicas de worker consumen el mismo topic mediante consumer group,
permitiendo paralelismo y reparto de particiones.

Flujo simplificado:

Kafka(votes) -> worker-1
			  -> worker-2
			  -> worker-3

### Evidencia en este repositorio

- Helm chart del servicio worker: worker/chart
- Automatizacion de despliegue por Helm en .github/workflows/ops.yml y .github/workflows/ops-push.yml.

Nota: para paralelismo efectivo, el topic debe tener suficientes particiones.

### Beneficios

- Escalado horizontal del procesamiento.
- Menor latencia de drenaje de cola.
- Mejor throughput bajo carga.

## Patron 2 - Bulkhead

### Problema que resuelve

Sin aislamiento por entorno, errores en staging pueden degradar production.

### Solucion aplicada

Se separan despliegues por namespace de Kubernetes:

- staging
- production

Los workflows de operaciones seleccionan el namespace segun rama o payload entrante,
y aplican helm upgrade en el entorno correcto.

### Evidencia en este repositorio

- Seleccion de entorno en .github/workflows/ops.yml y .github/workflows/ops-push.yml
- Despliegue con namespace en .github/workflows/infra.yml, .github/workflows/ops.yml y .github/workflows/ops-push.yml

### Beneficios

- Aislamiento operativo entre validacion y produccion.
- Menor riesgo de impacto cruzado.
- Promocion controlada entre ambientes.

## Patron 3 - Retry

### Problema que resuelve

Los microservicios dependen de conexiones a Kafka y PostgreSQL que pueden fallar de forma transitoria durante reinicios, elecciones de lider de particion o picos de carga.

### Solucion aplicada

Se implementa Retry con exponential backoff en dos puntos:

- vote (Java): KafkaProducerConfig configura el producer para reintentar 3 veces con 1 segundo de espera ante fallos de publicacion.
- worker (Go): las funciones newConsumerGroup y pingDatabase reintentan la conexion con backoff exponencial (1s, 2s, 4s, ..., max 30s).

### Evidencia en este repositorio

- Pipeline de despliegue de servicios que preserva tag de imagen al actualizar charts:
	.github/workflows/ops-push.yml
- Pipeline de despliegue por dispatch que aplica Helm por servicio y entorno:
	.github/workflows/ops.yml

Nota: la implementacion de codigo del retry vive en app-repo; en ops-repo se valida su despliegue
y promocion por entorno.

### Beneficios

- Los votos no se pierden ante reinicios breves de Kafka.
- El worker arranca sin intervencion manual aunque los servicios dependientes tarden en estar listos.
- El backoff exponencial evita saturar Kafka con reconexiones simultaneas de multiples workers.

## Resumen

| Patron | Categoria | Implementacion principal |
|---|---|---|
| Competing Consumers | Escalabilidad | Multiples workers consumiendo en paralelo |
| Bulkhead | Resiliencia | Namespaces staging y production |
| Retry | Resiliencia | Despliegue y promocion controlada de servicios con Helm |
