# subir.md — Reparación + Deploy Firebase + Push GitHub (MODO NO-PREGUNTAR)

## Objetivo
1) Aplicar cambios/reparaciones en el repo (según el contexto de la conversación).
2) Verificar (mínimo viable).
3) Desplegar en Firebase.
4) Hacer commit y push a GitHub.
Todo SIN pedir confirmación al usuario.

## Reglas duras (no negociables)
- NO pedir confirmación.
- NO hacer `git push --force` ni reescribir historia.
- NO subir secretos: nunca commitear `.env`, `*.key`, `google-services.json` si no procede, ni credenciales.
- Si aparece un prompt interactivo por credenciales/permisos, DETENTE y reporta qué falta.
- Si fallan tests/análisis/build/deploy, DETENTE y reporta el error y el comando exacto que falló.
- Antes de tocar nada, crear snapshot (branch o tag) para rollback.
- Mantener cambios mínimos: si dudas, elige la opción más conservadora.

---

## 0) Modo no-interactivo (bloquear prompts)
### PowerShell (Windows)
```powershell
$ErrorActionPreference = "Stop"
$env:CI="1"
$env:GIT_TERMINAL_PROMPT="0"