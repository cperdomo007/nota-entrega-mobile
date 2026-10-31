import test from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, verifyPassword, token, validToken, digest } from '../src/security.js';
import { noteSchema, validateLines, toCents } from '../src/validation.js';
import { createApp } from '../src/app.js';

test('passwords salted with scrypt; wrong passwords fail',async()=>{
  const first=await hashPassword('Test-password-123!'), second=await hashPassword('Test-password-123!');
  assert.notEqual(first,second);
  assert.equal(await verifyPassword('Test-password-123!',first),true);
  assert.equal(await verifyPassword('wrong',first),false);
  assert.equal(await verifyPassword('anything','invalid'),false);
});
test('tokens are random and persisted as hashes',()=>{
  const value=token(); assert(validToken(value)); assert.notEqual(value,token());
  assert.equal(digest(value).length,64); assert.notEqual(digest(value),value);
  assert.equal(validToken('guess'),false);
});
test('notes reject invalid dates, quantities, money and serials',()=>{
  const input={noteNumber:'NE1',noteDate:'2026-02-30',clientName:'Test',applyIVA:true,
    lines:[{productId:1,quantity:1,unitPrice:'1.23',serials:['ABC']}]};
  assert.equal(noteSchema.safeParse(input).success,false);
  input.noteDate='2026-10-30'; assert(noteSchema.safeParse(input).success);
  input.lines[0].quantity=1.5; assert.equal(noteSchema.safeParse(input).success,false);
  const products=[{id:1,hasSerial:true}];
  assert.equal(validateLines([{productId:1,quantity:2,unitPrice:'1',serials:['ABC']}],products),false);
  assert.equal(validateLines([{productId:1,quantity:2,unitPrice:'1',serials:['ABC','ABC']}],products),false);
  assert.equal(validateLines([{productId:1,quantity:1,unitPrice:'1.23',serials:['ABC']}],products),true);
  assert.equal(toCents('100.25'),10025);
});
test('all data endpoints require authentication and HTTPS',async()=>{
  const pool={query:async()=>[[{ok:1}]],execute:async()=>[[]]};
  const app=await createApp(pool,{requireHttps:false});
  const server=app.listen(0,'127.0.0.1'); await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  try {
    for(const path of ['clients','products','notes','notes/1','budgets','budgets/1','dashboard','config','auth/me','users']) {
      const response=await fetch(`${base}/api/mobile/v1/${path}`);
      assert.equal(response.status,401,path); assert.equal(response.headers.get('cache-control'),'no-store');
    }
    assert.equal((await fetch(`${base}/api/mobile/v1/products`,{headers:{Authorization:'Bearer invalid'}})).status,401);
  } finally { await new Promise(resolve=>server.close(resolve)); }
  const secure=await createApp(pool); const second=secure.listen(0,'127.0.0.1');
  await new Promise(resolve=>second.once('listening',resolve));
  try { assert.equal((await fetch(`http://127.0.0.1:${second.address().port}/api/mobile/v1/clients`)).status,426); }
  finally { await new Promise(resolve=>second.close(resolve)); }
});
