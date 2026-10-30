# Railway: API HTTPS desplegada

Proyecto: `c8f68696-5def-429c-af84-6b103e96ad59`, entorno production `49a069c2-ab5a-4ce7-bd78-630c813d6b2a`.

- MySQL existente: `9eda844c-a0a4-4c0b-85ea-f173ba610fc1` (MySQL).
- API: `b9936f5c-274e-4c0d-ab2e-505e3343215f` (nota-entrega-mobile).
- URL pública autorizada: `https://nota-entrega-mobile-production.up.railway.app`.
- Base del cliente: `https://nota-entrega-mobile-production.up.railway.app/api/mobile/v1/`.
- La conexión API→MySQL usa una referencia privada de Railway. No se agregaron conexiones MySQL al cliente ni se cambió la configuración de red del servicio MySQL existente.

## Configuración aplicada

Repositorio cperdomo007/nota-entrega-mobile, rama feature/flutter-initial-setup; Root Directory `/backend`; constructor Dockerfile; ruta `/backend/Dockerfile`; pre-deploy `npm run migrate`; start `npm start`; healthcheck `/health`. DATABASE_URL es la referencia `${{MySQL.MYSQL_URL}}`; las contraseñas permanecen en Railway. El dominio HTTPS dirige al puerto 8080 del servicio API.

Wait for CI y Watch Paths `/backend/**` están habilitados: cambios de documentación/Flutter no reinician el servidor. Una réplica; antes de escalar se debe sustituir el limitador de IP en memoria por uno distribuido. Sesiones, bloqueo por cuenta e idempotencia persisten en MySQL.

Config as Code está deprecado para servicios nuevos según la interfaz Railway. `backend/railway.json` conserva la descripción inicial para instalaciones compatibles, pero este servicio se configuró en Settings. No asumir que el archivo aplica automáticamente.

La migración autorizada creó mobile_users, mobile_sessions y mobile_note_requests sin alterar users ni tablas de negocio. No se realizaron escrituras de negocio de prueba en producción.

## HTTPS verificado

Desde fuera de Railway, usando validación TLS normal (sin deshabilitar certificados), /health respondió 200 y clients/products/notes/users/config sin token respondieron 401. Las respuestas incluyen Cache-Control: no-store. Login/salud son públicos; los datos necesitan un Bearer vigente y usuario activo. No se agregó registro público.

## Primer administrador: paso privado del propietario

El correo acordado está fuera del repositorio. La contraseña inicial la introduce el propietario, nunca en el chat. En Console del servicio API, ejecutar lo siguiente sustituyendo el correo de ejemplo por el acordado. Las contraseñas se leen sin mostrarlas y no quedan en el comando/historial:

```bash
read -r -s -p 'Nueva contraseña (mínimo 12 caracteres): ' NEW_USER_PASSWORD; echo
read -r -s -p 'Confirmar contraseña: ' PASSWORD_CONFIRM; echo
if [ "$NEW_USER_PASSWORD" = "$PASSWORD_CONFIRM" ]; then
  export NEW_USER_PASSWORD
  NEW_USER_EMAIL='admin@example.com' NEW_USER_NAME='Administrador' NEW_USER_ROLE='admin' npm run create-user
else
  echo 'Las contraseñas no coinciden; no se creó el usuario.'
fi
unset NEW_USER_PASSWORD PASSWORD_CONFIRM
```

El comando valida longitud 12–128, guarda solo scrypt y se niega a sobrescribir usuarios. Los demás usuarios se crean mediante POST users autenticado como admin o con el comando de servidor y rol user.

## APK conectado por HTTPS

`config/env.production.json` contiene únicamente la URL pública, sin secretos. Ejecutar `flutter build apk --debug --dart-define-from-file=config/env.production.json`. El workflow utiliza este archivo y publica `nota-entrega-https-debug`. No hace falta VPN para esta URL. El logo de Sumisistemas está incluido junto al icono de Nota Entrega.

Instalar el APK del commit que introduce esta configuración; los artefactos anteriores apuntaban a un dominio de ejemplo. La compilación y publicación del artefacto deben verificarse en la ejecución correspondiente. Para usar otro entorno, crear config/env.local.json (ignorado). Para escribir notas de prueba, usar staging; la integración automatizada exige una BD aislada terminada en `_test`.
