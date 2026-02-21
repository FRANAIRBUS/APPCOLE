# ColeConecta

App Flutter + Firebase multi-colegio para red privada de familias.

## Stack
- Flutter 3.x + Riverpod + GoRouter
- Firebase Auth, Firestore, Storage, Functions (Node 20), Messaging, Hosting

## Estructura
- `lib/features`: pantallas y módulos MVP
- `lib/services`: servicios de auth, invitaciones, chat y paths
- `lib/models`: modelos de dominio
- `functions`: Cloud Functions requeridas
- `firestore.rules`: aislamiento multi-colegio y chat privado

## Cloud Functions incluidas
- `redeemInviteCode`
- `getOrCreateChat`
- `deleteMyAccount`

## Setup
```bash
flutter pub get
cd functions && npm install
```

## Run
```bash
flutter run
```

## Web Deploy
```bash
flutter build web
firebase deploy
```
