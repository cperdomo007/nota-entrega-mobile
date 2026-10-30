# Validación del acceso con usuarios

Esta sección sustituye el estado de integración pendiente del prototipo OAuth inicial. Flutter 3.47.9 / Dart 3.13.7; Node 22.

- `flutter pub get`: se retiró flutter_appauth y se actualizó pubspec.lock.
- `flutter test --no-pub --coverage`: 18 pruebas aprobadas, incluidas login/almacenamiento, rotación y revocación, sesión inválida, formulario y creación de notas.
- `npm test` en backend: 4 pruebas aprobadas para contraseñas scrypt, tokens, validación y protección HTTPS/autenticación.
- `npm ci`: instalación independiente del backend verificada antes del PR.
- MySQL real: integración automatizada configurada en CI con mysql:8.4 y una base aislada `_test`. El resultado se consulta en la ejecución del commit; no se realizan pruebas de escritura en producción.
- GitHub Actions compila el APK con login de correo/contraseña y configura la API solo con env.example.json. El artefacto no apunta a Railway hasta compilar con el dominio real.

Railway: acceso de lectura confirmado al servicio MySQL solicitado. Tablas web visibles: clients, products, delivery_notes, note_lines, serials, company_config, users, presupuestos y listas de precios. No se ejecutó la migración ni se creó el administrador en ese servicio durante la preparación. El correo del administrador y su futura contraseña no se publican en el repositorio. La migración propuesta agrega mobile_users, mobile_sessions y mobile_note_requests; no altera las tablas web.

Antes de considerar operativa la conexión: desplegar el backend separado, ejecutar la migración autorizada, establecer la contraseña inicial privadamente, verificar salud/401/login/lecturas y configurar la URL en un nuevo APK. Pendientes en dispositivo: cámara, permisos, compartir y revisión visual. No hay firma release.
