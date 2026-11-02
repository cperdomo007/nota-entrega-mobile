import mysql from 'mysql2/promise';
export function createPool(url = process.env.DATABASE_URL) {
  if (!url) throw new Error('DATABASE_URL no configurada en el servidor');
  const uri = new URL(url);
  if (uri.protocol !== 'mysql:' || !uri.hostname || !uri.pathname.slice(1)) throw new Error('DATABASE_URL inválida');
  if (!['127.0.0.1','localhost','[::1]'].includes(uri.hostname) && !uri.hostname.endsWith('.railway.internal') && process.env.MYSQL_TLS !== 'true') throw new Error('Usa la red privada de Railway o MYSQL_TLS=true');
  return mysql.createPool({ host: uri.hostname, port: Number(uri.port || 3306),
    user: decodeURIComponent(uri.username), password: decodeURIComponent(uri.password),
    database: decodeURIComponent(uri.pathname.slice(1)), connectionLimit: 8,
    waitForConnections: true, queueLimit: 100, connectTimeout: 10000,
    charset: 'utf8mb4', timezone: 'Z', dateStrings: true,
    multipleStatements: false,
    ...(process.env.MYSQL_TLS === 'true' ? { ssl: { rejectUnauthorized: true } } : {}) });
}
export async function transaction(pool, work) {
  const connection = await pool.getConnection();
  try { await connection.beginTransaction(); const result = await work(connection); await connection.commit(); return result; }
  catch (error) { await connection.rollback(); throw error; }
  finally { connection.release(); }
}
