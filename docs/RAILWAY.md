# Desplegar la API móvil en Railway

Proyecto solicitado: `c8f68696-5def-429c-af84-6b103e96ad59`, entorno production `49a069c2-ab5a-4ce7-bd78-630c813d6b2a`, MySQL `9eda844c-a0a4-4c0b-85ea-f173ba610fc1` (nombre visible: MySQL). La lectura de Railway confirmó tablas web existentes; no se imprimen ni copian credenciales al repositorio.

## Servicio separado

1. Crear un servicio de API desde cperdomo007/nota-entrega-mobile, rama de esta implementación; **no reemplazar el servicio MySQL ni la web**.
2. Root Directory: `/backend`; archivo de configuración: `/backend/railway.json`. Dockerfile y comandos trabajan desde backend.
3. Variable privada del servidor: `DATABASE_URL=${{MySQL.MYSQL_URL}}`, referencia a la BD dentro del mismo proyecto/entorno. No usar la URL TCP pública en Flutter. El backend rechaza conexión MySQL pública sin TLS verificable. La red privada Railway es la vía prevista.
4. El pre-deploy ejecuta `npm run migrate`: crea únicamente las tres tablas móviles con `CREATE TABLE IF NOT EXISTS`. No hay DROP, ALTER de tablas web ni semillas de negocio. La creación debe estar autorizada sobre este entorno antes del despliegue.
5. Healthcheck `/health`. El proceso usa PORT de Railway. Generar dominio HTTPS para la API tras autorizar su acceso a la BD. Una réplica para el rate limiter en memoria; el bloqueo por usuario y las sesiones sí persisten en MySQL. Antes de escalar, usar limitador distribuido.

En producción se recomienda un usuario SQL dedicado, sin permisos de borrar/modificar esquema después de migrar: SELECT en clients/products/company_config; SELECT/INSERT en delivery_notes/note_lines/serials; SELECT/INSERT/UPDATE/DELETE en tablas móviles según las funciones del servidor. Preparar migración con credenciales administrativas por separado si se retira CREATE del usuario de ejecución. El código incluye capacidad de crear notas; no realiza escrituras de negocio hasta una petición autenticada.

## Primer administrador

Usar el correo acordado con el propietario; los valores siguientes son ejemplos. No se crea una contraseña predeterminada. En una terminal segura del servicio definir temporalmente estas variables (NO en el chat, código, APK ni logs):

- `NEW_USER_EMAIL=admin@example.com`
- `NEW_USER_NAME=Administrador`
- `NEW_USER_ROLE=admin`
- `NEW_USER_PASSWORD`: contraseña privada de al menos 12 caracteres.

Ejecutar `npm run create-user`. El comando se niega a sobrescribir cuentas existentes; no imprime hash ni contraseña. Retirar NEW_USER_PASSWORD del entorno al terminar. El arranque de la API nunca crea ni restablece contraseñas automáticamente. Los demás usuarios se crean por un administrador con POST users o con el mismo comando y rol user.

## Conectar el APK

Crear `config/env.local.json` (ignorado): `{"API_BASE_URL":"https://DOMINIO-API/api/mobile/v1/"}`. Compilar `flutter build apk --debug --dart-define-from-file=config/env.local.json`. El endpoint es público; las credenciales MySQL permanecen exclusivamente en Railway. No se puede usar el enlace del panel Railway como API_BASE_URL.

## Comprobación del despliegue

1. /health devuelve 200. GET /api/mobile/v1/clients sin token devuelve 401.
2. Iniciar sesión con el administrador y consultar auth/me, dashboard, clientes/productos reales; comprobar que ninguna respuesta contiene passwordHash.
3. Renovar y cerrar sesión; comprobar que los tokens antiguos ya no autorizan.
4. Probar la creación de notas e idempotencia **en una copia de staging** antes de hacer una prueba de escritura sobre producción.
5. Instalar el APK configurado, ingresar manualmente la contraseña y comprobar acceso. La prueba no debe requerir compartir la contraseña con el agente.

Consultar docs/VALIDATION.md y el PR para distinguir código preparado de acciones de Railway realmente ejecutadas.
