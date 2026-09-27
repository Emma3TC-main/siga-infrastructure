# Infrastructure: instrucciones locales

- Fuente de verdad: `../siga-documentation/SIGA_Documentacion_Tecnica_Final_v1.2/`: manual técnico/ADR, `database/logical_model.md`, `database/physical_model.sql`, `database/dictionary.md`, `diagramas/**/*.puml`, `api/*.yaml`, `especificaciones/` y `trazabilidad/`.
- Excluir derivados `diagramas_render/` y `out/`. No rediseñar contratos ni arquitectura para acomodar configuraciones.
- Inventariar Git, contenedores, redes, volúmenes y puertos antes de modificar. No sobrescribir `.env` existentes ni rotar credenciales de volúmenes inicializados automáticamente.
- Nuevas instalaciones: `scripts/Team-Local.ps1` y `compose/compose.team.yml`, proyecto/volúmenes aislados por instancia, imágenes por digest y secretos generados en `.env.<instance>`. El entorno previo sigue con `compose/compose.local.yml` y `.env.local`: no recrearlo para validar instalaciones nuevas. No combinar con el Compose orientativo general; publicar solo en loopback.
- Identity/Flyway crea y posee `iam`; Infrastructure solo aprovisiona login y permisos. Nunca importar el modelo SQL completo como bootstrap de Identity.
- En nuevas instancias, `siga_iam_test` pertenece a una base dedicada y no tiene CONNECT sobre `siga`; preservar esta separación y las credenciales al reiniciar. Init debe fallar si hay datos del proyecto pero falta su archivo de secretos.
- Verificar `docker compose config --quiet`, salud, conexión y pruebas del servicio afectado/contratos antes de declarar éxito. No imprimir configuración expandida con secretos.
- No `down -v`, prune, reset/clean/rebase/merge/push, despliegues ni recursos cloud en trabajo local.
