# Railway: API privada desplegada

Proyecto: `c8f68696-5def-429c-af84-6b103e96ad59`, entorno production `49a069c2-ab5a-4ce7-bd78-630c813d6b2a`.

- MySQL existente: `9eda844c-a0a4-4c0b-85ea-f173ba610fc1` (MySQL).
- Nueva API: `b9936f5c-274e-4c0d-ab2e-505e3343215f` (nota-entrega-mobile).
- DNS privado: `nota-entrega-mobile.railway.internal`.
- **Sin dominio público**, por decisión del propietario. No agregar exposición pública sin nueva autorización.

## Configuración aplicada

Repositorio cperdomo007/nota-entrega-mobile, rama feature/flutter-initial-setup; Root Directory `/backend`; constructor Dockerfile; ruta `/backend/Dockerfile`; pre-deploy `npm run migrate`; start `npm start`; healthcheck `/health`. DATABASE_URL es una referencia privada `${{MySQL.MYSQL_URL}}`; no se copiaron contraseñas al código ni al cliente.

Se habilitó Wait for CI y Watch Paths `/backend/**`: cambios de documentación/Flutter no deben reiniciar el servidor. El servicio utiliza una réplica en la red privada del proyecto. El límite por IP es en memoria; antes de escalar, sustituirlo por un limitador distribuido. Las sesiones, bloqueo por cuenta e idempotencia persisten en MySQL.

La interfaz actual de Railway informa que Config as Code está deprecado y que servicios nuevos no pueden habilitarlo. `backend/railway.json` conserva la descripción inicial para instalaciones compatibles, pero **no se usó para configurar este servicio**: los valores se establecieron y verificaron en Settings. No asumir que ese archivo aplica automáticamente.

La migración autorizada creó `mobile_users`, `mobile_sessions` y `mobile_note_requests` y terminó con «Tablas móviles verificadas; esquema web conservado». No modifica `users` ni las tablas de negocio. /health devolvió 200 y una consulta a clients sin token devolvió 401 desde una consola local simulando los encabezados del ingreso HTTPS. No se realizaron escrituras de negocio de prueba en producción.

## Primer administrador: paso privado del propietario

El correo acordado está fuera del repositorio. No se ha creado una contraseña ni una cuenta con contraseña predeterminada. En Console del servicio API, ejecutar lo siguiente sustituyendo el correo de ejemplo por el acordado. Las contraseñas se leen sin mostrarlas y no aparecen en el comando ni en el historial:

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

El comando valida longitud 12–128, guarda solo scrypt y se niega a sobrescribir un usuario existente. Retira la contraseña de las variables al finalizar. La entrada, confirmación y envío de la contraseña inicial corresponden al propietario; no compartirla por chat.

Los usuarios posteriores se crean mediante POST users autenticado como administrador o mediante el comando de servidor con rol user. La API no ofrece registro público.

## Acceso desde Android

La red privada de Railway no es accesible directamente desde un teléfono en Internet. **Este despliegue privado aún no ofrece una URL utilizable por el APK.** Hace falta una VPN o pasarela privada con HTTPS y DNS/certificado válidos, y autorización para configurarla. No usar la URL del panel Railway ni una URL MySQL como API_BASE_URL; no deshabilitar TLS ni incluir credenciales MySQL en Flutter.

Cuando exista esa vía, crear config/env.local.json (ignorado): `{"API_BASE_URL":"https://DOMINIO-PRIVADO/api/mobile/v1/"}` y compilar el APK con ese archivo. No confundir el APK de CI, configurado con un dominio de ejemplo, con uno que ya tenga conectividad a producción.

La imagen de Docker y la API fueron verificadas en CI con MySQL aislado. Para escribir notas de prueba, usar primero staging; las pruebas de integración se niegan a usar una base cuyo nombre no termine en `_test`.
