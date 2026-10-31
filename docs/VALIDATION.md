# Validación 0.5.0+8: edición y login

- `flutter analyze --no-pub`: sin incidencias. `flutter test --no-pub --coverage`: 29 pruebas aprobadas, incluidas edición de cliente/producto/nota/presupuesto, datos precargados, seriales, línea manual sin producto, número conservado y limpieza de credenciales rechazadas. Fallos de conexión conservan los campos.
- Seis pruebas unitarias/de seguridad del backend aprobadas; GET y PUT sin sesión protegidos. Seis PDF reales verificados con pypdf, conservando formatos, seriales e importes sin códigos de producto.
- Integración MySQL aislada preparada para edición atómica, totales, número original, eliminación de seriales reemplazados, rollback de ediciones inválidas, idempotencia y versiones obsoletas. GitHub Actions ejecuta esa integración, Docker y los APK optimizados por arquitectura: consultar el run del commit publicado para su resultado.

Sin migraciones nuevas ni escrituras ficticias de prueba en producción. Pendiente comprobar formularios, teclado, cámara y compartir en dispositivo; firma de producción.

## Historial de distribución

# Validación 0.4.1+7: distribución optimizada

La versión 0.4.0+6 con altas y creación de presupuestos pasó CI: https://github.com/cperdomo007/nota-entrega-mobile/actions/runs/41155733557 (commit 2780b84fc719ce1567ac6192f5246e926d093bab). Incluye 23 pruebas Flutter, seis del backend, integración MySQL aislada, seis PDF verificados, Docker y compilación Android debug.

0.4.1+7 conserva esas funciones y cambia el empaquetado a release por arquitectura, con firma de prueba para instalación. El workflow verifica la estructura AOT/ABI, firma, permiso INTERNET y debuggable=false, y mide los tamaños reales en apk-sizes.json. Consultar el run del commit publicado para el resultado de esta compilación. No hay cambios del backend ni del esquema por esta optimización. Pendientes: pruebas en teléfono y firma de producción.

## Historial de funcionalidades

# Validación 0.4.0+6: altas y numeración

- Análisis Flutter sin incidencias; 23 pruebas aprobadas. Nuevos flujos: alta de cliente, alta de producto con control de serial, creación de presupuesto con descripción editable y número de vista previa de solo lectura.
- Backend: seis pruebas unitarias/de seguridad aprobadas; incluyen DDMMAAAAHHMM en America/Caracas, medianoche, fin de mes, año bisiesto, validación del catálogo y bloqueo de POST sin sesión.
- Seis PDF generados por Flutter y verificados con pypdf; formatos, seriales e importes conservados sin códigos de producto.
- Integración MySQL 8.4 aislada preparada para altas compartidas, RIF/código únicos, claves idempotentes separadas por entidad, presupuestos sin seriales, IVA y carrera entre documentos del mismo minuto. GitHub Actions ejecuta esta integración, Docker y la compilación APK: consultar el run del commit publicado para su resultado.

Sin migraciones nuevas ni renumeración del historial. Las únicas escrituras de prueba se ejecutan en la base aislada _test de CI. No se crean registros ficticios en producción. Pendientes: comprobación de formularios/teclado, cámara y compartir en un teléfono; firma release.

## Historial 0.3.0+5: formatos PDF

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --coverage`: 20 pruebas aprobadas; incluye buscar/abrir presupuestos y exportar ambas plantillas.
- `python tool/verify_pdf.py` con pypdf 6.10.0: seis PDF reales de Flutter verificados. Confirma importes, fechas, datos fiscales, firmas, ausencia de códigos/IDs, caso sin IVA y conservación de todos los seriales en documentos multipágina.
- PDF de muestra A4 renderizados con Poppler y revisados visualmente; también páginas de continuación y cierre del caso de 500 seriales. Muestras con datos ficticios, sin publicar los PDF originales de clientes.
- Backend: cuatro pruebas de seguridad locales aprobadas, incluyendo presupuestos/listado y detalle sin sesión → 401.
- La integración MySQL aislada agrega consulta/búsqueda/detalle de presupuestos históricos y cabecera fiscal. Se ejecuta en CI, junto a Docker y la compilación APK de esta versión; consultar el run asociado al commit publicado para su resultado.

Nuevas consultas del backend sin cambios en migraciones ni esquema de producción. Presupuestos es solo lectura; datos existentes de la web. No se ejecutaron fixtures ni escrituras de negocio de prueba en producción. En un teléfono siguen pendientes login, cámara/permisos y selector nativo de compartir. Firma release no configurada.

## Historial: login por correo y API MySQL (0.2.x)

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
