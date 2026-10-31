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
    await pool.query('INSERT INTO company_config (businessName,ivaRate,rif,address,phone1,email,website) SELECT ?,?,?,?,?,?,? WHERE NOT EXISTS (SELECT 1 FROM company_config)',
      ['Test Company','16.00','J-00000000-0','Test Address','000-0000','test@example.com','https://example.com']);
    let clock = new Date('2026-10-30T21:10:00Z');
    const app=await createApp(pool,{requireHttps:false,now:()=>clock});
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
    assert.equal((await request('notes/next-number',{access})).body.noteNumber,'301020261710');
    assert.equal((await request('budgets/next-number',{access})).body.budgetNumber,'301020261710');
    const detail=(await request(`notes/${one.body.id}`,{access})).body;
    assert.equal(detail.noteNumber,'301020261710');
    assert.equal(detail.subtotal,'100.25'); assert.equal(detail.ivaAmount,'16.04'); assert.equal(detail.total,'116.29');
    assert.deepEqual(detail.lines[0].serials,['SERIAL-'+suffix]);
    assert.equal(detail.company.businessName,'Test Company');
    assert.equal(detail.company.rif,'J-00000000-0'); assert.equal(detail.company.address,'Test Address');
    // A historical/manual budget line must not depend on a current product.
    const [budget]=await pool.execute('INSERT INTO budgets (budgetNumber,budgetDate,clientName,subtotal,applyIVA,ivaAmount,total,observations) VALUES (?,?,?,?,?,?,?,?)',
      [`BUDGET-${suffix}`,'2026-10-30','Budget Client','100.25',false,'0.00','100.25','Test terms']);
    await pool.execute('INSERT INTO budget_lines (budgetId,productId,description,quantity,unitPrice,lineTotal) VALUES (?,?,?,?,?,?)',
      [budget.insertId,null,'Historical manual description',1,'100.25','100.25']);
    const budgetList=await request(`budgets?q=${encodeURIComponent(suffix)}`,{access});
    assert.equal(budgetList.status,200);
    assert(budgetList.body.items.some(b=>b.id===budget.insertId && b.applyIVA===false));
    const quote=await request(`budgets/${budget.insertId}`,{access});
    assert.equal(quote.status,200); assert.equal(quote.body.company.businessName,'Test Company');
    assert.equal(quote.body.company.email,'test@example.com');
    assert.equal(quote.body.total,'100.25'); assert.equal(quote.body.applyIVA,false);
    assert.equal(quote.body.lines[0].description,'Historical manual description');
    assert.equal(quote.body.lines[0].productId,null);
    assert.equal((await request('budgets/0',{access})).status,422);
    assert.equal((await request('budgets/2147483647',{access})).status,404);
    assert.equal((await request('budgets',{method:'POST',access,data:{}})).status,422);
    const [[count]]=await pool.execute('SELECT COUNT(*) AS count FROM delivery_notes WHERE noteNumber=?',[detail.noteNumber]);
    assert.equal(count.count,1);
    assert.equal((await request('notes',{method:'POST',access,key,data:{...input,clientName:'Changed'}})).status,409);
    const bad={...input,noteNumber:`BAD-${suffix}`,lines:[{...input.lines[0],quantity:2,serials:['DUP','DUP']}]};
    const [[beforeBad]]=await pool.query('SELECT COUNT(*) AS count FROM delivery_notes');
    const badKey=token();
    assert.equal((await request('notes',{method:'POST',access,key:badKey,data:bad})).status,422);
    const [[rolled]]=await pool.execute('SELECT COUNT(*) AS count FROM mobile_note_requests WHERE userId=? AND requestKey=?',[user.insertId,badKey]); assert.equal(rolled.count,0);
    const [[badNotes]]=await pool.query('SELECT COUNT(*) AS count FROM delivery_notes'); assert.equal(badNotes.count,beforeBad.count);
    // Writes use the web tables and the same idempotency ledger, namespaced
    // by entity type. No production database or business data is used here.
    const entityKey=token();
    const clientInput={name:`Created ${suffix}`,rif:`J-${suffix}`,email:'client@example.com'};
    const clientOne=await request('clients',{method:'POST',access,key:entityKey,data:clientInput});
    const clientTwo=await request('clients',{method:'POST',access,key:entityKey,data:clientInput});
    assert.equal(clientOne.status,201); assert.equal(clientOne.body.id,clientTwo.body.id);
    const clientCollision=await request('clients',{method:'POST',access,key:token(),data:clientInput});
    assert.equal(clientCollision.status,409); assert.equal(clientCollision.body.code,'CATALOG_DUPLICATE');
    assert((await request(`clients?q=${suffix}`,{access})).body.items.some(c=>c.id===clientOne.body.id));
    const productInput={name:`Created Product ${suffix}`,barcode:`SKU-${suffix}`,price:'20.25',unit:'UN',stock:3,hasSerial:true};
    const productOne=await request('products',{method:'POST',access,key:entityKey,data:productInput});
    const productTwo=await request('products',{method:'POST',access,key:entityKey,data:productInput});
    assert.equal(productOne.status,201); assert.equal(productOne.body.id,productTwo.body.id);
    assert.equal((await request('products',{method:'POST',access,key:token(),data:productInput})).status,409);
    assert.equal((await request('products',{method:'POST',access,key:token(),data:{...productInput,price:'0'}})).status,422);
    const duplicateNote=await request('notes',{method:'POST',access,key:token(),data:{...input,noteNumber:'ignored'}});
    assert.equal(duplicateNote.status,409); assert.equal(duplicateNote.body.code,'DOCUMENT_NUMBER_EXISTS');
    const budgetInput={budgetDate:'2026-10-30',clientName:'Created Budget Client',applyIVA:true,ivaRate:'16.00',
      lines:[{productId:productOne.body.id,description:'Persisted budget description',quantity:2,unitPrice:'20.25'}]};
    const [budgetOne,budgetTwo]=await Promise.all([
      request('budgets',{method:'POST',access,key:entityKey,data:budgetInput}),request('budgets',{method:'POST',access,key:entityKey,data:budgetInput})]);
    assert.equal(budgetOne.status,201); assert.equal(budgetTwo.status,201); assert.equal(budgetOne.body.id,budgetTwo.body.id);
    const createdBudget=(await request(`budgets/${budgetOne.body.id}`,{access})).body;
    assert.equal(createdBudget.budgetNumber,'301020261710'); assert.equal(createdBudget.subtotal,'40.50');
    assert.equal(createdBudget.ivaAmount,'6.48'); assert.equal(createdBudget.total,'46.98');
    assert.equal(createdBudget.lines[0].description,'Persisted budget description');
    assert.equal((await request('budgets',{method:'POST',access,key:token(),data:budgetInput})).body.code,'DOCUMENT_NUMBER_EXISTS');
    clock = new Date('2026-10-30T21:11:00Z');
    const minuteRace=await Promise.all([request('notes',{method:'POST',access,key:token(),data:input}),request('notes',{method:'POST',access,key:token(),data:input})]);
    assert.deepEqual(minuteRace.map(r=>r.status).sort(),[201,409]);
    assert.equal(minuteRace.find(r=>r.status===201).body.noteNumber,'301020261711');
    assert.equal((await request('notes',{method:'POST',access,key,data:input})).body.id,one.body.id);
    assert.equal((await request('budgets',{method:'POST',access,key:entityKey,data:budgetInput})).body.id,budgetOne.body.id);
    const regular=await request('users',{method:'POST',access,data:{email:`user-${suffix}@example.com`,name:'User',password,role:'user'}});
    assert.equal(regular.status,201);
    const regularLogin=(await request('auth/login',{method:'POST',data:{email:regular.body.email,password}})).body;
    assert.equal((await request('users',{access:regularLogin.accessToken})).status,403);
    assert.equal((await request('clients',{method:'POST',access:regularLogin.accessToken,key:token(),data:{name:'Regular user client'}})).status,201);
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
