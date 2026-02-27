# Auditoría técnica y de seguridad (rama actual)

## Contexto detectado
- Stack principal: Flutter/Dart + Firebase (Firestore, Auth, Storage, Cloud Functions Node.js).
- Patrón de backend: reglas Firestore + funciones callable `functions/index.js`.

## Hallazgos críticos

1. **Moderación con ruta arbitraria (riesgo de abuso interno)**
   - Estado anterior: `moderationHideTarget` aceptaba cualquier `targetPath` que empezase por `schools/` y hacía `set(..., merge:true)` sobre ese documento.
   - Riesgo: un moderador/admin podía ocultar documentos fuera del dominio de moderación esperado (por ejemplo `schools/{id}/users/{uid}` o recursos internos).
   - Mitigación aplicada: validación estricta de rutas permitidas (posts, events, event comments), comprobación de existencia del documento objetivo y traza de moderación (`moderatedByUid`, `moderatedAt`).

2. **Borrado de cuenta incompleto en chats con alto volumen**
   - Estado anterior: en `deleteMyAccount` se anonimizaban como máximo 500 mensajes por chat.
   - Riesgo: fuga de datos residual en cuentas con más de 500 mensajes en un chat.
   - Mitigación aplicada: paginación completa por lotes de 500 hasta agotar resultados.

3. **Cliente enviando `schoolId` incorrecto en canje de invitación**
   - Estado anterior: `InviteService` enviaba `schoolId = Firebase.app().options.projectId`.
   - Riesgo: el backend interpreta `schoolId` como ID de colegio, no de proyecto; provoca inconsistencias y errores funcionales de onboarding.
   - Mitigación aplicada: eliminar el envío de `schoolId` desde ese servicio cuando no se conoce el ID real del colegio.

## Hallazgos importantes (sin parche en esta iteración)

1. **Enumeración completa de escuelas en funciones sensibles**
   - `resolveSchoolIdForUid` y partes de `redeemInviteCode` recorren toda la colección `schools`.
   - Impacto: coste/latencia creciente, riesgo de timeouts con escala.
   - Recomendación: usar `users/{uid}.schoolId` como fuente canónica + validación puntual de membresía; migrar legacy con job offline.

2. **Lectura amplia de documento de escuela en reglas**
   - Regla actual: `match /schools/{schoolId} { allow read: if signedIn(); }`
   - Impacto: usuarios autenticados pueden leer metadatos de cualquier escuela aunque no pertenezcan a ella.
   - Recomendación: `allow get, list: if inSchool(schoolId) || isRoot();` (o separar metadatos públicos/no públicos).

3. **`setUserRole` depende solo de custom claim root**
   - Si un flujo operativo asigna claim root por error, la función permite escalar privilegios.
   - Recomendación: doble control: claim root + lista allowlist en Firestore (`adminConfig/rootUids`) + auditoría con reason obligatorio.

4. **Sin protección explícita de App Check en callables**
   - Riesgo: mayor superficie de abuso automatizado si se filtran credenciales de usuario.
   - Recomendación: exigir App Check en funciones expuestas y monitorizar rechazos.

5. **Hardening de contenido en mensajería/comentarios**
   - Actualmente hay límites de longitud, pero no saneado semántico ni políticas anti-abuso avanzadas.
   - Recomendación: normalización unicode, detección simple de spam repetitivo, cooldown adaptativo por usuario/IP/huella de dispositivo.

## Recomendaciones operativas de producción

- Añadir tests de integración para Cloud Functions críticas:
  - moderación (rutas válidas/inválidas),
  - borrado de cuenta con >500 mensajes,
  - onboarding/canje de invitación en escenarios multi-colegio.
- Activar alertas de presupuesto/cuotas en Firestore y Functions.
- Añadir dashboards de:
  - errores por función,
  - latencia p95/p99,
  - ratio `resource-exhausted` en comentarios.
- Definir política de retención para `adminAudit` y registros de moderación.

## Estado de esta iteración
- Se aplicaron correcciones en backend y cliente para los 3 hallazgos críticos anteriores.
