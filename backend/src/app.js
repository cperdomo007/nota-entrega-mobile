import express from 'express';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { transaction } from './db.js';
import { credentials, digest, hashPassword, sessionValues, validToken, verifyPassword } from './security.js';
import { loginSchema, userSchema, noteSchema, clientSchema, productSchema, budgetSchema, validateLines, toCents, toMoney } from './validation.js';
import { documentNumber } from './document-number.js';
const publicUser = user => ({ id: user.id, email: user.email, name: user.name, role: user.role });
const fail = (status, message) => Object.assign(new Error(message), { status });
const tokenBody = z.object({ refreshToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/) }).strict();
const pageSchema = z.object({ q: z.string().trim().max(200).default(''),
  limit: z.coerce.number().int().min(1).max(50).default(50), offset: z.coerce.number().int().min(0).max(10000000).default(0) });
export async function createApp(pool, { requireHttps = true, now = () => new Date() } = {}) {
  documentNumber(now()); // Validate timezone configuration before listening.
  const app = express();
  app.disable('x-powered-by');
  // Railway supplies one trusted ingress proxy. Never use trust proxy=true.
  app.set('trust proxy', 1);
  app.use(helmet());
  app.use((req, res, next) => { res.set('Cache-Control','no-store'); next(); });
  app.get('/health', async (_req,res) => { await pool.query('SELECT 1'); res.json({ok:true}); });
  app.use((req,_res,next) => {
    if (requireHttps && !req.secure) throw fail(426,'Se requiere HTTPS');
    next();
  });
  app.use(express.json({limit:'512kb'}));
  app.use(rateLimit({windowMs:60000,limit:300,standardHeaders:'draft-8',legacyHeaders:false}));
  const routes = express.Router();
  app.use('/api/mobile/v1',routes);
  const authLimit = rateLimit({windowMs:15*60000,limit:30,standardHeaders:'draft-8',legacyHeaders:false});
  const dummyHash = await hashPassword('dummy-password-not-an-account');
  routes.post('/auth/login',authLimit,async (req,res) => {
    const input = loginSchema.parse(req.body);
    const result = await transaction(pool,async db => {
      const [users] = await db.execute('SELECT *,lockedUntil>UTC_TIMESTAMP(3) AS locked FROM mobile_users WHERE email=? FOR UPDATE',[input.email]);
      const user = users[0];
      const matches = await verifyPassword(input.password,user?.passwordHash || dummyHash);
      if (!user || !user.active || user.locked || !matches) {
        if (user && !user.locked) await db.execute('UPDATE mobile_users SET lockedUntil=IF(failedAttempts+1>=5,DATE_ADD(UTC_TIMESTAMP(3), INTERVAL 15 MINUTE),NULL),failedAttempts=IF(failedAttempts+1>=5,0,failedAttempts+1) WHERE id=?',[user.id]);
        return null;
      }
      await db.execute('UPDATE mobile_users SET failedAttempts=0,lockedUntil=NULL WHERE id=?',[user.id]);
      const pair = credentials();
      // Remove expired sessions for this user without retaining raw tokens.
      await db.execute('DELETE FROM mobile_sessions WHERE userId=? AND refreshExpiresAt<=UTC_TIMESTAMP(3)',[user.id]);
      await db.execute('INSERT INTO mobile_sessions (userId,accessHash,refreshHash,accessExpiresAt,refreshExpiresAt) VALUES (?,?,?,?,?)',[user.id,...sessionValues(pair)]);
      return {...pair,user:publicUser(user)};
    });
    if (!result) throw fail(401,'Correo o contraseña incorrectos');
    res.json(result);
  });
  routes.post('/auth/refresh',authLimit,async (req,res) => {
    const {refreshToken} = tokenBody.parse(req.body);
    const result = await transaction(pool,async db => {
      const [sessions] = await db.execute('SELECT s.id,s.userId,u.email,u.name,u.role FROM mobile_sessions s JOIN mobile_users u ON u.id=s.userId WHERE s.refreshHash=? AND s.refreshExpiresAt>UTC_TIMESTAMP(3) AND u.active=1 FOR UPDATE',[digest(refreshToken)]);
      const session = sessions[0];
      if (!session) return null;
      const pair = credentials();
      await db.execute('UPDATE mobile_sessions SET accessHash=?,refreshHash=?,accessExpiresAt=?,refreshExpiresAt=? WHERE id=?',[...sessionValues(pair),session.id]);
      return {...pair,user:publicUser({...session,id:session.userId})};
    });
    if (!result) throw fail(401,'Sesión expirada');
    res.json(result);
  });
  routes.post('/auth/logout',authLimit,async(req,res) => {
    const {refreshToken} = tokenBody.parse(req.body);
    await pool.execute('DELETE FROM mobile_sessions WHERE refreshHash=?',[digest(refreshToken)]);
    res.sendStatus(204);
  });
  routes.use(async (req,_res,next) => {
    const authorization = req.headers.authorization;
    if (!authorization?.startsWith('Bearer ') || !validToken(authorization.slice(7))) throw fail(401,'Inicia sesión');
    const [users] = await pool.execute('SELECT u.id,u.email,u.name,u.role FROM mobile_sessions s JOIN mobile_users u ON u.id=s.userId WHERE s.accessHash=? AND s.accessExpiresAt>UTC_TIMESTAMP(3) AND s.refreshExpiresAt>UTC_TIMESTAMP(3) AND u.active=1',[digest(authorization.slice(7))]);
    if (!users[0]) throw fail(401,'Sesión expirada');
    req.user = users[0]; next();
  });
  routes.get('/auth/me',(req,res) => res.json({user:publicUser(req.user)}));
  routes.post('/users',async(req,res) => {
    if (req.user.role !== 'admin') throw fail(403,'Solo administradores');
    const input = userSchema.parse(req.body);
    const passwordHash = await hashPassword(input.password);
    const [result] = await pool.execute('INSERT INTO mobile_users (email,name,passwordHash,role) VALUES (?,?,?,?)',[input.email,input.name,passwordHash,input.role]);
    res.status(201).json({id:result.insertId,email:input.email,name:input.name,role:input.role});
  });
  routes.get('/users',async(req,res) => {
    if (req.user.role !== 'admin') throw fail(403,'Solo administradores');
    const {limit,offset} = pageSchema.parse(req.query);
    const [items] = await pool.query(`SELECT id,email,name,role,active FROM mobile_users ORDER BY id LIMIT ${limit} OFFSET ${offset}`);
    res.json({items});
  });
  routes.patch('/users/:id',async(req,res) => {
    if (req.user.role !== 'admin') throw fail(403,'Solo administradores');
    const id = z.coerce.number().int().positive().parse(req.params.id);
    const {active} = z.object({active:z.boolean()}).strict().parse(req.body);
    if (id === req.user.id) throw fail(422,'No puedes desactivar tu propia cuenta');
    await transaction(pool,async db => {
      const [result] = await db.execute('UPDATE mobile_users SET active=? WHERE id=?',[active,id]);
      if (!result.affectedRows) throw fail(404,'Usuario no encontrado');
      if (!active) await db.execute('DELETE FROM mobile_sessions WHERE userId=?',[id]);
    });
    res.sendStatus(204);
  });
  routes.get('/dashboard',async(_req,res) => {
    const [[row]] = await pool.query('SELECT (SELECT COUNT(*) FROM clients) AS clients,(SELECT COUNT(*) FROM products) AS products,(SELECT COUNT(*) FROM delivery_notes) AS notes');
    res.json(row);
  });
  routes.get('/config',async(_req,res) => {
    const [[row]] = await pool.query('SELECT businessName,ivaRate FROM company_config ORDER BY id LIMIT 1');
    res.json(row || {ivaRate:'16.00'});
  });
  for (const [path,table,fields,filter] of [
    ['clients','clients','id,name,rif,address,phone,email,contact','name LIKE ? OR rif LIKE ?'],
    ['products','products','id,name,barcode,description,category,price,unit,hasSerial,stock','name LIKE ? OR barcode LIKE ?'],
    ['notes','delivery_notes','id,noteNumber,noteDate,clientName,subtotal,ivaAmount,total,applyIVA','noteNumber LIKE ? OR clientName LIKE ?'],
    ['budgets','budgets','id,budgetNumber,budgetDate,clientName,subtotal,ivaAmount,total,applyIVA','budgetNumber LIKE ? OR clientName LIKE ?'],
  ]) routes.get(`/${path}`,async(req,res) => {
    const {q,limit,offset} = pageSchema.parse(req.query);
    const search = `%${q.replaceAll('!','!!').replaceAll('%','!%').replaceAll('_','!_')}%`;
    const where = q ? ` WHERE ${filter.replaceAll('LIKE ?', "LIKE ? ESCAPE '!'")}` : '';
    const [rows] = await pool.query(`SELECT ${fields} FROM ${table}${where} ORDER BY id DESC LIMIT ${limit} OFFSET ${offset}`,q ? [search,search] : []);
    res.json({items:rows.map(row => ({...row,...('hasSerial' in row ? {hasSerial:!!row.hasSerial} : {}),...('applyIVA' in row ? {applyIVA:!!row.applyIVA} : {})}))});
  });
  routes.get('/notes/next-number',(_req,res) => res.json({noteNumber:documentNumber(now())}));
  routes.get('/budgets/next-number',(_req,res) => res.json({budgetNumber:documentNumber(now())}));
  routes.get('/notes/:id',async(req,res) => {
    const id = z.coerce.number().int().positive().parse(req.params.id);
    const [[note]] = await pool.execute('SELECT * FROM delivery_notes WHERE id=?',[id]);
    if (!note) throw fail(404,'Nota no encontrada');
    const [lines] = await pool.execute('SELECT l.*,p.name AS productName FROM note_lines l LEFT JOIN products p ON p.id=l.productId WHERE l.noteId=? ORDER BY l.id',[id]);
    const [serials] = await pool.execute('SELECT s.lineId,s.serial FROM serials s JOIN note_lines l ON l.id=s.lineId WHERE l.noteId=? ORDER BY s.id',[id]);
    const [[company]] = await pool.query('SELECT businessName,rif,address,phone1,phone2,email,website FROM company_config ORDER BY id LIMIT 1');
    res.json({...note,applyIVA:!!note.applyIVA,company:company || {},companyName:company?.businessName || '',lines:lines.map(l => ({...l,serials:serials.filter(s=>s.lineId===l.id).map(s=>s.serial)}))});
  });
  // Budgets are read-only: amounts/descriptions come from the shared web data.
  routes.get('/budgets/:id',async(req,res) => {
    const id = z.coerce.number().int().positive().parse(req.params.id);
    const [[budget]] = await pool.execute('SELECT * FROM budgets WHERE id=?',[id]);
    if (!budget) throw fail(404,'Presupuesto no encontrado');
    const [lines] = await pool.execute('SELECT * FROM budget_lines WHERE budgetId=? ORDER BY id',[id]);
    const [[company]] = await pool.query('SELECT businessName,rif,address,phone1,phone2,email,website FROM company_config ORDER BY id LIMIT 1');
    res.json({...budget,applyIVA:!!budget.applyIVA,company:company || {},lines});
  });
  // Reuse the existing idempotency ledger without schema changes. Legacy note
  // keys stay unchanged; catalog/budget keys contain ':' (forbidden in external
  // keys) and a hash. For these namespaces noteId holds the created entity ID.
  const createOnce = async(req,kind,input,work) => {
    const raw = z.string().regex(/^[A-Za-z0-9_-]{24,96}$/).parse(req.headers['idempotency-key']);
    const requestKey = kind === 'notes' ? raw : `${kind}:${digest(raw)}`;
    const payloadHash = digest(JSON.stringify(input));
    try {
      return await transaction(pool,async db => {
        await db.execute('INSERT INTO mobile_note_requests (userId,requestKey,payloadHash) VALUES (?,?,?) ON DUPLICATE KEY UPDATE requestKey=requestKey',[req.user.id,requestKey,payloadHash]);
        const [[previous]] = await db.execute('SELECT payloadHash,noteId FROM mobile_note_requests WHERE userId=? AND requestKey=? FOR UPDATE',[req.user.id,requestKey]);
        if (previous.payloadHash !== payloadHash) throw fail(409,'La clave ya se usó con otros datos');
        if (previous.noteId) return {id:previous.noteId};
        const result = await work(db);
        await db.execute('UPDATE mobile_note_requests SET noteId=? WHERE userId=? AND requestKey=?',[result.id,req.user.id,requestKey]);
        return result;
      });
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') error.publicCode = ['notes','budgets'].includes(kind) ? 'DOCUMENT_NUMBER_EXISTS' : 'CATALOG_DUPLICATE';
      throw error;
    }
  };
  routes.post('/clients',async(req,res) => {
    const input = clientSchema.parse(req.body);
    const result = await createOnce(req,'clients',input,async db => {
      const [created] = await db.execute('INSERT INTO clients (name,rif,address,phone,email,contact) VALUES (?,?,?,?,?,?)',
        [input.name,input.rif||null,input.address||null,input.phone||null,input.email||null,input.contact||null]);
      return {id:created.insertId};
    });
    res.status(201).json(result);
  });
  routes.post('/products',async(req,res) => {
    const input = productSchema.parse(req.body);
    const result = await createOnce(req,'products',input,async db => {
      const [created] = await db.execute('INSERT INTO products (name,barcode,description,category,price,unit,hasSerial,stock) VALUES (?,?,?,?,?,?,?,?)',
        [input.name,input.barcode||null,input.description||null,input.category||null,toMoney(toCents(input.price)),input.unit,input.hasSerial,input.stock]);
      return {id:created.insertId};
    });
    res.status(201).json(result);
  });
  routes.post('/notes',async(req,res) => {
    const input = noteSchema.parse(req.body);
    const result = await createOnce(req,'notes',input,async db => {
      const ids = [...new Set(input.lines.map(l=>l.productId))];
      const [products] = await db.query(`SELECT id,hasSerial FROM products WHERE id IN (${ids.map(()=>'?').join(',')})`,ids);
      if (!validateLines(input.lines,products)) throw fail(422,'Productos, importes o seriales inválidos');
      const [[config]] = await db.query('SELECT ivaRate FROM company_config ORDER BY id LIMIT 1');
      const rate = Number(config?.ivaRate ?? 16);
      if (!Number.isFinite(rate) || rate < 0 || rate > 100) throw fail(503,'Configuración fiscal inválida');
      if (input.ivaRate !== undefined && Number(input.ivaRate) !== rate) throw fail(409,'La tasa de IVA cambió; recarga el formulario');
      const subtotal = input.lines.reduce((sum,l)=>sum+toCents(l.unitPrice)*l.quantity,0);
      const iva = input.applyIVA ? Math.round(subtotal*rate/100) : 0;
      if (subtotal+iva > 999999999999) throw fail(422,'Importe demasiado grande');
      const number = documentNumber(now());
      const [created] = await db.execute('INSERT INTO delivery_notes (noteNumber,noteDate,clientName,clientRif,clientAddress,clientPhone,clientContact,subtotal,applyIVA,ivaAmount,total,observations,deliveredBy,receivedBy) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [number,input.noteDate,input.clientName,input.clientRif||null,input.clientAddress||null,input.clientPhone||null,input.clientContact||null,toMoney(subtotal),input.applyIVA,toMoney(iva),toMoney(subtotal+iva),input.observations||null,input.deliveredBy||null,input.receivedBy||null]);
      for (const line of input.lines) {
        const [createdLine] = await db.execute('INSERT INTO note_lines (noteId,productId,quantity,unitPrice,lineTotal) VALUES (?,?,?,?,?)',[created.insertId,line.productId,line.quantity,toMoney(toCents(line.unitPrice)),toMoney(toCents(line.unitPrice)*line.quantity)]);
        for (const serial of line.serials) await db.execute('INSERT INTO serials (lineId,serial) VALUES (?,?)',[createdLine.insertId,serial]);
      }
      return {id:created.insertId,noteNumber:number};
    });
    res.status(201).json(result);
  });
  routes.post('/budgets',async(req,res) => {
    const input = budgetSchema.parse(req.body);
    const result = await createOnce(req,'budgets',input,async db => {
      const ids = [...new Set(input.lines.map(l=>l.productId).filter(Boolean))];
      if (ids.length) {
        const [products] = await db.query(`SELECT id FROM products WHERE id IN (${ids.map(()=>'?').join(',')})`,ids);
        if (products.length !== ids.length) throw fail(422,'Producto no encontrado');
      }
      const [[config]] = await db.query('SELECT ivaRate FROM company_config ORDER BY id LIMIT 1');
      const rate = Number(config?.ivaRate ?? 16);
      if (!Number.isFinite(rate) || rate < 0 || rate > 100) throw fail(503,'Configuración fiscal inválida');
      if (input.ivaRate !== undefined && Number(input.ivaRate) !== rate) throw fail(409,'La tasa de IVA cambió');
      const subtotal = input.lines.reduce((sum,l)=>sum+toCents(l.unitPrice)*l.quantity,0);
      const iva = input.applyIVA ? Math.round(subtotal*rate/100) : 0;
      if (subtotal+iva > 999999999999) throw fail(422,'Importe demasiado grande');
      const number = documentNumber(now());
      const [created] = await db.execute('INSERT INTO budgets (budgetNumber,budgetDate,clientName,clientRif,clientAddress,clientPhone,clientContact,subtotal,applyIVA,ivaAmount,total,observations) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [number,input.budgetDate,input.clientName,input.clientRif||null,input.clientAddress||null,input.clientPhone||null,input.clientContact||null,toMoney(subtotal),input.applyIVA,toMoney(iva),toMoney(subtotal+iva),input.observations||null]);
      for (const line of input.lines) await db.execute('INSERT INTO budget_lines (budgetId,productId,description,quantity,unitPrice,lineTotal) VALUES (?,?,?,?,?,?)',
        [created.insertId,line.productId||null,line.description,line.quantity,toMoney(toCents(line.unitPrice)),toMoney(toCents(line.unitPrice)*line.quantity)]);
      return {id:created.insertId,budgetNumber:number};
    });
    res.status(201).json(result);
  });
  app.use((_req,res)=>res.status(404).json({error:'Ruta no encontrada'}));
  app.use((error,_req,res,_next)=>{
    const status = error instanceof z.ZodError ? 422 : error.code === 'ER_DUP_ENTRY' ? 409 :
      error.type === 'entity.too.large' ? 413 : error instanceof SyntaxError ? 400 : error.status || 500;
    res.status(status).json({...(['DOCUMENT_NUMBER_EXISTS','CATALOG_DUPLICATE'].includes(error.publicCode) ? {code:error.publicCode} : {}),error:status===500 ? 'Error interno' : status===422 ? 'Datos inválidos' : status===409 ? 'Conflicto: revisa numeración, IVA o datos enviados' : status===401 ? 'Credenciales o sesión inválidas' : status===403 ? 'Acceso denegado' : status===404 ? 'No encontrado' : 'No se pudo completar la operación'});
  });
  return app;
}
