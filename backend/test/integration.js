import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createPool } from '../src/db.js';
import { createApp } from '../src/app.js';
import { hashPassword, token } from '../src/security.js';

test('MySQL authentication, rotation, permissions, shared data and atomic note idempotency',async()=>{
  const url=process.env.TEST_DATABASE_URL;
  assert(url && new URL(url).pathname.endsWith('_test'),'Use only an isolated database ending in _test');
  const pool=createPool(url); let server;
  try {
    for(const file of ['../migrations/001_mobile_auth.sql','./fixtures.sql']) {
      const sql=await readFile(new URL(file,import.meta.url),'utf8');
      for(const statement of sql.split(';').map(s=>s.trim()).filter(Boolean)) await pool.query(statement);
    }
    const suffix=token().slice(0,10), email=`admin-${suffix}@example.com`, password='Test-password-123!';
    const [user]=await pool.execute('INSERT INTO mobile_users (email,name,passwordHash,role) VALUES (?,?,?,?)',[email,'Test',await hashPassword(password),'admin']);
    const [product]=await pool.query('INSERT INTO products (name,price,hasSerial,unit) VALUES (?,?,?,?)',['Test Router','100.25',true,'UN']);
    await pool.query('INSERT INTO company_config (businessName,ivaRate) SELECT ?,? WHERE NOT EXISTS (SELECT 1 FROM company_config)',['Test Company','16.00']);
    const app=await createApp(pool,{requireHttps:false});
    server=app.listen(0,'127.0.0.1'); await new Promise(resolve=>server.once('listening',resolve));
    const base=`http://127.0.0.1:${server.address().port}/api/mobile/v1/`;
    const request=async(path,{method='GET',data,access,key}={})=>{
      const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json',
        ...(access?{Authorization:`Bearer ${access}`} : {}),...(key?{'Idempotency-Key':key}:{})},
        ...(data?{body:JSON.stringify(data)}:{})});
      return {status:response.status,body:response.status===204?null:await response.json()};
    };
    assert.equal((await request('auth/login',{method:'POST',data:{email,password:'wrong'}})).status,401);
    const logged=await request('auth/login',{method:'POST',data:{email,password}});
    assert.equal(logged.status,200); assert.equal(logged.body.user.email,email);
    const {accessToken:access,refreshToken:refresh}=logged.body;
    const [[stored]]=await pool.execute('SELECT accessHash,refreshHash FROM mobile_sessions WHERE userId=?',[user.insertId]);
    assert.notEqual(stored.accessHash,access); assert.notEqual(stored.refreshHash,refresh);
    assert.equal((await request('auth/me',{access})).status,200);
    const items=(await request('products?q=Test%20Router',{access})).body.items;
    assert(items.some(p=>p.id===product.insertId && p.hasSerial===true));
    const input={noteNumber:`TEST-${suffix}`,noteDate:'2026-10-30',clientName:'Test Client',applyIVA:true,ivaRate:'16.00',
      lines:[{productId:product.insertId,quantity:1,unitPrice:'100.25',serials:['SERIAL-'+suffix]}]};
    const key=token();
    const [one,two]=await Promise.all([request('notes',{method:'POST',access,key,data:input}),request('notes',{method:'POST',access,key,data:input})]);
    assert.equal(one.status,201); assert.equal(two.status,201); assert.equal(one.body.id,two.body.id);
    const detail=(await request(`notes/${one.body.id}`,{access})).body;
    assert.equal(detail.subtotal,'100.25'); assert.equal(detail.ivaAmount,'16.04'); assert.equal(detail.total,'116.29');
    assert.deepEqual(detail.lines[0].serials,['SERIAL-'+suffix]);
    const [[count]]=await pool.execute('SELECT COUNT(*) AS count FROM delivery_notes WHERE noteNumber=?',[input.noteNumber]);
    assert.equal(count.count,1);
    assert.equal((await request('notes',{method:'POST',access,key,data:{...input,clientName:'Changed'}})).status,409);
    const bad={...input,noteNumber:`BAD-${suffix}`,lines:[{...input.lines[0],quantity:2,serials:['DUP','DUP']}]};
    const badKey=token();
    assert.equal((await request('notes',{method:'POST',access,key:badKey,data:bad})).status,422);
    const [[rolled]]=await pool.execute('SELECT COUNT(*) AS count FROM mobile_note_requests WHERE userId=? AND requestKey=?',[user.insertId,badKey]); assert.equal(rolled.count,0);
    const [[badNotes]]=await pool.execute('SELECT COUNT(*) AS count FROM delivery_notes WHERE noteNumber=?',[bad.noteNumber]); assert.equal(badNotes.count,0);
    const regular=await request('users',{method:'POST',access,data:{email:`user-${suffix}@example.com`,name:'User',password,role:'user'}});
    assert.equal(regular.status,201);
    const regularLogin=(await request('auth/login',{method:'POST',data:{email:regular.body.email,password}})).body;
    assert.equal((await request('users',{access:regularLogin.accessToken})).status,403);
    assert.equal((await request('users/'+regular.body.id,{method:'PATCH',access,data:{active:false}})).status,204);
    assert.equal((await request('auth/me',{access:regularLogin.accessToken})).status,401);
    assert.equal((await request('auth/refresh',{method:'POST',data:{refreshToken:regularLogin.refreshToken}})).status,401);
    const rotated=await request('auth/refresh',{method:'POST',data:{refreshToken:refresh}});
    assert.equal(rotated.status,200); assert.notEqual(rotated.body.refreshToken,refresh);
    assert.equal((await request('auth/refresh',{method:'POST',data:{refreshToken:refresh}})).status,401);
    assert.equal((await request('auth/me',{access})).status,401);
    assert.equal((await request('auth/logout',{method:'POST',data:{refreshToken:rotated.body.refreshToken}})).status,204);
    assert.equal((await request('auth/me',{access:rotated.body.accessToken})).status,401);
    for(let i=0;i<5;i++) assert.equal((await request('auth/login',{method:'POST',data:{email,password:'wrong'}})).status,401);
    assert.equal((await request('auth/login',{method:'POST',data:{email,password}})).status,401);
    const [[locked]]=await pool.execute('SELECT lockedUntil IS NOT NULL AS locked FROM mobile_users WHERE id=?',[user.insertId]); assert.equal(locked.locked,1);
  } finally { if(server) await new Promise(resolve=>server.close(resolve)); await pool.end(); }
});
