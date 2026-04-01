# Demo Runbook

Este runbook define una secuencia corta para demostrar el flujo CI/CD entre app-repo y ops-repo.

## 1. Verificacion inicial

1. Confirmar disponibilidad de workflows en GitHub Actions.
2. Confirmar que existen secretos de kubeconfig para staging y production.
3. Validar estado de cluster en staging:
   kubectl get pods -n staging

## 2. Simular cambio en app-repo

1. Crear rama feature desde develop en app-repo.
2. Aplicar un cambio pequeno en vote, result o worker.
3. Abrir PR hacia develop y validar checks de CI.
4. Merge a develop.

## 3. Validar despliegue automatico en staging

1. Verificar en app-repo la cadena de jobs:
   detect changes -> test -> build and push -> trigger ops
2. Verificar en ops-repo ejecucion de ops.yml.
3. Confirmar pods actualizados:
   kubectl get pods -n staging

## 4. Promocion a production

1. Crear y aprobar PR de develop a main en app-repo.
2. Confirmar nuevo trigger app-image-ready hacia ops-repo.
3. Verificar ejecucion de ops.yml con environment=production.
4. Confirmar estado de pods:
   kubectl get pods -n production

## 5. Verificacion de infraestructura base

1. Si hubo cambios en infrastructure/**, validar ejecucion de infra.yml.
2. Confirmar recursos base por entorno:
   kubectl get pods -n staging
   kubectl get pods -n production

## Resultado esperado

- Feature PR solo ejecuta CI.
- Merge a develop despliega a staging.
- Merge a main despliega a production.
- Despliegue usa imagen con tag inmutable sha-commit.
