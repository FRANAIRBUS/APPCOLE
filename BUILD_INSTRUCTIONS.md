# ColeConecta — BUILD_INSTRUCTIONS para Codex (Flutter + Firebase)

Este documento define las instrucciones de implementación **end-to-end** para construir y dejar operativo el MVP de ColeConecta en producción.

## 1) Objetivo de producto

Construir una app privada multi‑colegio (iOS/Android/Web) para familias con:

- Publicaciones comunitarias (Busco/Ofrezco, Talento, BiblioCircular, Veteranos).
- Eventos entre familias.
- Matching por clase (“Mi Clase”).
- Chat interno privado 1:1.
- Aislamiento estricto por `schoolId`.
- Seguridad y cumplimiento de privacidad (sin teléfonos visibles, sin fotos de menores, borrado completo de cuenta).

---

## 2) Stack y estándares obligatorios

### Frontend
- Flutter 3.x
- Material 3
- Riverpod para estado
- GoRouter para navegación

### Backend Firebase
- Firebase Auth: Email/Password + Google + Apple
- Cloud Firestore
- Firebase Storage (foto de adulto opcional)
- Cloud Functions (Node.js 20)
- Firebase Cloud Messaging
- Firebase Hosting (web)

### Calidad técnica
- Código de producción: tipado correcto, control de errores, validaciones server-side.
- Multi-tenant estricto por `schools/{schoolId}`.
- Reglas de seguridad Firestore mínimas pero robustas.
- Operaciones idempotentes donde aplique (especialmente en creación de chat determinista).

---

## 3) Arquitectura multi‑colegio (obligatoria)

**Todo dato de negocio vive bajo el prefijo:**

`schools/{schoolId}/...`

No guardar datos funcionales fuera de este namespace (salvo Auth y metadatos técnicos inevitables).

---

## 4) Modelo de datos Firestore

## 4.1 Usuarios
`schools/{schoolId}/users/{uid}`

Campos mínimos:
- `displayName: string`
- `role: "parent" | "admin" | "moderator"`
- `photoUrl?: string` (solo adulto)
- `children: Array<{ name: string; age: number; classId: string }>`
- `classIds: string[]`
- `professional?: string`
- `fcmTokens?: string[]`
- `createdAt: timestamp`

## 4.2 Posts
`schools/{schoolId}/posts/{postId}`

Campos mínimos:
- `module: "busco_ofrezco" | "talento" | "biblio" | "veteranos"`
- `type: string`
- `title: string`
- `body: string`
- `authorUid: string`
- `createdAt: timestamp`
- `expiresAt?: timestamp`
- `status: "active" | "closed" | "deleted"`

## 4.3 Eventos
`schools/{schoolId}/events/{eventId}`

Campos mínimos:
- `title: string`
- `description: string`
- `dateTime: timestamp`
- `place: string`
- `organizerUid: string`
- `createdAt: timestamp`

## 4.4 Chat interno 1:1 (multi-colegio)

### Colección de chats
`schools/{schoolId}/chats/{chatId}`

Campos obligatorios:
- `participants: [uidA, uidB]` (exactamente 2 en MVP)
- `participantMap: { [uid]: true }` (soporte de queries por participante)
- `lastMessage: string`
- `lastMessageAt: timestamp`
- `createdAt: timestamp`
- `createdByUid: string`

### Subcolección de mensajes
`schools/{schoolId}/chats/{chatId}/messages/{messageId}`

Campos obligatorios:
- `senderUid: string`
- `text: string`
- `createdAt: timestamp`
- `status: "sent" | "deleted"`

### chatId determinista
Para evitar chats duplicados:

`chatId = min(uidA, uidB) + "_" + max(uidA, uidB)`

---

## 5) UX mínima del MVP

## 5.1 Navegación base (Bottom Tabs)
1. Busco / Ofrezco
2. Entre Padres (eventos)
3. Mi Clase
4. Chat
5. Perfil

## 5.2 Flujos chat requeridos

### Flujo A — Desde Mi Clase
- Usuario abre “Mi Clase”.
- Selecciona perfil de otro padre/madre.
- Pulsa botón **“Mensaje”**.
- Se ejecuta `getOrCreateChat(withUid)`.
- Navega a `ChatScreen(chatId)`.

### Flujo B — Desde Perfil
- En perfil público de otro usuario mostrar botón **“Mensaje”**.
- Mismo comportamiento de creación/entrada de chat 1:1.

### Flujo C — Tab Chat
- Pantalla `ChatsScreen`: listado de chats ordenado por `lastMessageAt desc`.
- Cada item muestra: nombre interlocutor, preview de `lastMessage`, hora relativa.
- Al pulsar, abrir `ChatScreen(chatId)` con stream en tiempo real.

### Modo de conexión para MVP
- **Elegir modo simple**: Mensaje directo (sin solicitud previa).
- Opcional posterior: flujo con `connections/{id}` y estado `accepted`.

---

## 6) Cloud Functions requeridas

## 6.1 `redeemInviteCode(code)`
Responsabilidad:
- Validar invitación activa en `schools/{schoolId}/inviteCodes/{code}`.
- Comprobar expiración y usos máximos.
- Incrementar `uses` de forma transaccional.
- Crear/actualizar perfil de usuario en `schools/{schoolId}/users/{uid}`.

Validaciones:
- Rechazar códigos expirados, no existentes o agotados.
- Idempotencia para no duplicar efectos por reintentos.

## 6.2 `getOrCreateChat(withUid)`
Responsabilidad:
- Obtener `schoolId` del caller desde su documento de usuario.
- Verificar que `withUid` pertenece al mismo `schoolId`.
- Generar `chatId` determinista.
- Crear doc de chat si no existe (transacción o create-if-absent).
- Devolver `{ chatId, schoolId }`.

Validaciones:
- `withUid` distinto de caller.
- Participantes exactos 2.
- `participantMap` consistente con `participants`.

## 6.3 `sendMessage(chatId, text)` (opcional recomendado)
Responsabilidad:
- Validar que caller es participante.
- Crear mensaje en `messages`.
- Actualizar `lastMessage` y `lastMessageAt` del chat.
- Enviar push al otro participante (si tiene token).

Nota MVP:
- Se puede enviar mensaje desde cliente + reglas estrictas.
- Para seguridad/anti-spam superior, mover envío a Function.

## 6.4 `deleteMyAccount()`
Responsabilidad:
- Eliminar perfil, contenido propio (posts/mensajes relevantes), foto en Storage y usuario Auth.
- Operación segura y auditada (logs).

---

## 7) Notificaciones push (FCM) mínimo viable

- Guardar `fcmTokens: string[]` en `schools/{schoolId}/users/{uid}`.
- Al enviar mensaje, notificar al otro participante:
  - Título: `Nuevo mensaje`
  - Body: preview corto del texto
  - Datos: `chatId`, `schoolId`, `senderUid`
- Manejar tokens inválidos eliminándolos en backend.

---

## 8) Reglas Firestore (añadir/ajustar en firestore.rules)

Objetivo: solo participantes del chat y del mismo colegio pueden leer/escribir.

Implementar con helper existente `sameSchool(schoolId)` y validaciones sobre auth.

```rules
match /schools/{schoolId}/chats/{chatId} {
  allow read: if sameSchool(schoolId) &&
    request.auth.uid in resource.data.participants;

  allow create: if sameSchool(schoolId) &&
    request.resource.data.participants.size() == 2 &&
    request.auth.uid in request.resource.data.participants;

  allow update: if sameSchool(schoolId) &&
    request.auth.uid in resource.data.participants;

  match /messages/{messageId} {
    allow read: if sameSchool(schoolId) &&
      request.auth.uid in get(/databases/$(database)/documents/schools/$(schoolId)/chats/$(chatId)).data.participants;

    allow create: if sameSchool(schoolId) &&
      request.auth.uid in get(/databases/$(database)/documents/schools/$(schoolId)/chats/$(chatId)).data.participants &&
      request.resource.data.senderUid == request.auth.uid;

    allow update, delete: if sameSchool(schoolId) &&
      resource.data.senderUid == request.auth.uid;
  }
}
```

Recomendación adicional de hardening:
- Restringir campos actualizables de chat (evitar que cliente muta `participants`).
- Limitar longitud de `text` y sanitizar en cliente/backend.

---

## 9) Pantallas Flutter a implementar (mínimo)

Requeridas:
- `ChatsScreen` (lista de chats)
- `ChatScreen(chatId)` (stream de mensajes + composer)

Integración obligatoria:
- Botón “Mensaje” desde `Mi Clase`.
- Botón “Mensaje” desde `Perfil` de otro usuario.
- Tab dedicado `Chat` en navegación principal.

Comportamiento:
- Scroll invertido o anclado al final en conversación.
- Indicador de envío y estado básico (`sent`, `deleted`).
- Manejo de estados vacíos/errores/carga.

---

## 10) Estructura esperada del repo

```text
lib/
  features/
    auth/
    posts/
    events/
    chat/
    matching/
    profile/
  services/
  models/
functions/
firestore.rules
firebase.json
README.md
```

---

## 11) Privacidad y cumplimiento

Requisitos funcionales:
- No mostrar teléfonos.
- No almacenar/mostrar fotos de menores.
- Foto de adulto opcional.
- Borrado completo de cuenta disponible y funcional.

Requisitos de seguridad:
- Aislamiento de datos por colegio mediante reglas + paths.
- Acceso a chat estrictamente por participantes.
- Edición de contenido por autor o rol permitido.

---

## 12) Pasos de instalación y despliegue

```bash
# Flutter app
flutter pub get

# Firebase Functions
cd functions
npm install

# Ejecutar app
cd ..
flutter run

# Build web
flutter build web
firebase deploy
```

---

## 13) Criterios de aceptación MVP (DoD)

Debe cumplirse todo:
- Registro/login con Email, Google y Apple.
- Entrada por código de invitación de colegio.
- Publicación en Busco/Ofrezco.
- Creación de evento en Entre Padres.
- Matching en Mi Clase por `classIds`.
- Chat privado 1:1 funcional (crear/leer/enviar).
- Reglas Firestore impiden acceso cross-school y no participantes.
- Borrado de cuenta elimina datos asociados.

---

## 14) Checklist de implementación para Codex

1. Verificar estructura actual del repo y no romper módulos existentes.
2. Completar/ajustar modelos de datos de chat (`participants`, `participantMap`, `status`).
3. Implementar `getOrCreateChat` en Cloud Functions con transacción.
4. Implementar opcional `sendMessage` + FCM.
5. Actualizar `firestore.rules` según política de participantes y sameSchool.
6. Implementar `ChatsScreen` y mejorar `ChatScreen` con stream robusto.
7. Conectar botón “Mensaje” en Mi Clase y Perfil.
8. Probar flujos E2E con dos usuarios del mismo colegio y uno de otro colegio.
9. Actualizar README con setup, reglas y módulos implementados.
10. Validar despliegue de Functions/Rules/Hosting.

---

## 15) Decisión MVP fijada

**Modo de conexión elegido para MVP:** mensaje directo sin solicitud previa.

Backlog post-MVP:
- Solicitudes de conexión (`connections`)
- Bloquear/reportar usuarios
- Moderación avanzada y rate limiting anti-spam

---

## 16) Prompt breve alternativo (copiar/pegar)

> Añade chat interno 1:1 multi-colegio en Flutter + Firebase. Implementa Firestore schema `schools/{schoolId}/chats/{chatId}` con `participants`, `participantMap` y subcolección `messages`. Implementa `ChatsScreen` y `ChatScreen` con stream en tiempo real, `chatId` determinista, botón “Mensaje” en perfil y en “Mi Clase”, reglas Firestore para participantes, Cloud Function `getOrCreateChat(withUid)` y opcional `sendMessage(chatId,text)` con FCM al receptor. Integra todo en el repo y actualiza README con setup y criterios MVP.

