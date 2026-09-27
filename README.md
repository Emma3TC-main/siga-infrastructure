# siga-infrastructure

La receta para nuevas instalaciones está en `compose/compose.team.yml`, administrada por `scripts/Team-Local.ps1`: proyecto y volúmenes por instancia, puertos configurables en loopback, credenciales generadas e imágenes por digest. PostgreSQL prepara los logins/bases; cada servicio conserva su ownership de schema y migraciones.

Seguir la [guía única del equipo](../siga-identity-service/docs/LOCAL.md). Incluye instalación inicial, arranque habitual, pruebas, MinIO opcional, parada sin pérdida de datos y resolución de conflictos. Referencia sin secretos: `compose/.env.team.example`.

El entorno anterior `compose/compose.local.yml` + `.env.local` sigue conservado. No mezclarlo con la receta nueva ni con `compose/compose.yml` (plantilla general). No reutilizar sus volúmenes/contraseñas para ensayos limpios y no ejecutar `down -v` ni prune.

Fuente canónica: `../siga-documentation/SIGA_Documentacion_Tecnica_Final_v1.2/`. [Evidencia local](../siga-identity-service/docs/CIERRE_LOCAL_2026-09-26.md); [decisiones pendientes, no aprobadas](../siga-identity-service/docs/PROPUESTAS_CONTRATO_Y_REFRESH.md).
