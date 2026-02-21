# ColeConecta MVP (Flutter + Firebase)

MVP multi-colegio para iOS/Android/Web con aislamiento por `schoolId`.

## Módulos incluidos
- Busco / Ofrezco
- Entre Padres (lista + base para calendario)
- Mi Clase (matching por `classIds`)
- Perfil
- Talento del Cole
- BiblioCircular
- Trucos de los Veteranos
- Primer Día, Cero Dudas
- Red de Confianza (normas + reportes)

## Estructura
- `lib/` Flutter app (go_router + riverpod)
- `functions/` Cloud Functions Node 20
- `firestore.rules` reglas multi-tenant por colegio
- `firestore.indexes.json` índices para posts/events
- `firebase.json` configuración Firestore/Functions/Hosting

## Instalación
1. `flutter pub get`
2. `firebase login`
3. `firebase init` (seleccionar Firestore, Functions, Hosting)
4. `flutterfire configure`
5. Sustituir valores de `lib/firebase_options.dart` por los generados por FlutterFire
6. `cd functions && npm install && cd ..`

## Ejecución local
- Móvil: `flutter run`
- Web: `flutter run -d chrome`

## Deploy web (Firebase Hosting)
1. `flutter build web`
2. `firebase deploy --only hosting`

## Deploy backend
- `firebase deploy --only firestore:rules,firestore:indexes,functions`

## Notas iOS / Android
- Google Sign-In requiere configuración de SHA-1/SHA-256 (Android) y reversed client id (iOS).
- Apple Sign-In requiere capability en Xcode y Service ID si se usa en web.
- Photo profile Storage path: `schools/{schoolId}/users/{uid}/profile.jpg`.

## Functions incluidas
- `redeemInviteCode(code, childName, childAge, classId?)`
- `deleteMyAccount(schoolId)`
- `moderationHideTarget(targetPath)`
