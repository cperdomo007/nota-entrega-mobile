import { readFile } from 'node:fs/promises';
import { createPool } from './db.js';
import { hashPassword } from './security.js';
import { userSchema } from './validation.js';
const pool = createPool();
try {
  if (process.argv[2] === 'migrate') {
    const sql = await readFile(new URL('../migrations/001_mobile_auth.sql', import.meta.url), 'utf8');
    for (const statement of sql.split(';').map(s => s.trim()).filter(Boolean)) await pool.query(statement);
    console.log('Tablas móviles verificadas; esquema web conservado.');
  } else if (process.argv[2] === 'create-user') {
    const user = userSchema.parse({ email: process.env.NEW_USER_EMAIL, name: process.env.NEW_USER_NAME,
      password: process.env.NEW_USER_PASSWORD, role: process.env.NEW_USER_ROLE || 'user' });
    const passwordHash = await hashPassword(user.password);
    await pool.execute('INSERT INTO mobile_users (email,name,passwordHash,role) VALUES (?,?,?,?)',
      [user.email,user.name,passwordHash,user.role]);
    console.log('Usuario creado. No se imprimen contraseña ni hash.');
  } else throw new Error('Usa migrate o create-user');
} catch (error) {
  console.error(error.code === 'ER_DUP_ENTRY' ? 'El usuario ya existe; no se modificó.' : 'Operación fallida. Revisa configuración y permisos.');
  process.exitCode = 1;
} finally { await pool.end(); }
