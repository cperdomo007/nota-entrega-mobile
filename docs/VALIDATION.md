# Validación: login por correo y API MySQL

Flutter 3.47.9 / Dart 3.13.7; Node 22. Commit de código verificado: `6d3b072f3c0c7fbc23f237afc70f99504c1365ec`.

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --coverage`: 18 pruebas aprobadas (incluye login, almacenamiento, rotación, cierre, formulario y flujo de notas).
- `npm ci` y `npm test` en backend: instalación limpia y 4 pruebas de seguridad aprobadas.
- CI: integración real con mysql:8.4 en base aislada `_test`, aprobada; cubre permisos, bloqueo, revocación, rotación, desactivación, datos compartidos y creación concurrente idempotente con rollback.
- CI: Dockerfile construido y APK debug con el nuevo login compilado y publicado.
- Ejecución verificada: https://github.com/cperdomo007/nota-entrega-mobile/actions/runs/41143105444 . La configuración del APK usa dominio de ejemplo.

Railway, con autorización específica del propietario:

- Servicio API separado `b9936f5c-274e-4c0d-ab2e-505e3343215f` desplegado, conectado por referencia privada a MySQL.
- Migración aditiva ejecutada correctamente; tablas web conservadas.
- Desde Console, `/health` respondió 200 y `/api/mobile/v1/clients` sin token respondió 401 (solicitud local con X-Forwarded-Proto=https para comprobar la autenticación detrás del ingreso).
- Tras autorización explícita posterior del propietario, se publicó el dominio HTTPS nota-entrega-mobile-production.up.railway.app. Desde Internet, con validación TLS normal: health 200; clients/products/notes/users/config sin token 401; Cache-Control no-store.
- Se habilitaron espera de CI y despliegues limitados a cambios `/backend/**`.

El propietario confirmó que la consola mostró «Usuario creado» tras establecer privadamente su contraseña. Debe instalarse el APK que usa config/env.production.json para alcanzar la API HTTPS real, en vez de los artefactos anteriores con dominio de ejemplo; el inicio de sesión en un teléfono aún requiere comprobación manual. No se verificó un login de producción ni se publicaron credenciales. Cámara, permisos, compartir PDF y revisión visual en dispositivo siguen pendientes; firma release no configurada. No se ejecutaron fixtures ni escrituras de negocio de prueba en producción.

La configuración HTTPS se incorpora en la versión 0.2.2+4, conservando el logo de Sumisistemas. El workflow compila con config/env.production.json y publica nota-entrega-https-debug. Consultar el resultado del commit de esta configuración antes de afirmar una nueva compilación exitosa.
