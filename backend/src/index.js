import { createApp } from './app.js';
import { createPool } from './db.js';
const pool = createPool();
await pool.query('SELECT id FROM mobile_users LIMIT 0');
const app = await createApp(pool);
const server = app.listen(Number(process.env.PORT || 3000), '0.0.0.0', () => console.log('API móvil iniciada'));
const shutdown = () => { server.close(async () => { await pool.end(); process.exit(0); }); setTimeout(() => process.exit(1), 10000).unref(); };
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
