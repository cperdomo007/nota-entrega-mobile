import test from 'node:test';
import assert from 'node:assert/strict';
import { documentNumber } from '../src/document-number.js';
import { clientSchema, productSchema, budgetSchema } from '../src/validation.js';

test('DDMMAAAAHHMM uses Caracas business time, including midnight and leap day',()=>{
  assert.equal(documentNumber(new Date('2026-10-30T21:10:59Z'),'America/Caracas'),'301020261710');
  assert.equal(documentNumber(new Date('2026-11-01T03:59:00Z'),'America/Caracas'),'311020262359');
  assert.equal(documentNumber(new Date('2026-11-01T04:00:00Z'),'America/Caracas'),'011120260000');
  assert.equal(documentNumber(new Date('2028-03-01T03:00:00Z'),'America/Caracas'),'290220282300');
});

test('catalog and budgets validate names, ranges, email, prices and historical descriptions',()=>{
  assert(clientSchema.safeParse({name:' Cliente ',email:''}).success);
  assert.equal(clientSchema.safeParse({name:' ',email:'bad'}).success,false);
  assert.equal(clientSchema.safeParse({name:'Cliente',phone:'x'.repeat(21)}).success,false);
  assert(productSchema.safeParse({name:'Router',price:'100.25',hasSerial:true}).success);
  for(const price of ['0.00','-1','1.234','100000000.00']) assert.equal(productSchema.safeParse({name:'Router',price}).success,false);
  assert.equal(productSchema.safeParse({name:'Router',price:'1.00',stock:-1}).success,false);
  assert(budgetSchema.safeParse({budgetDate:'2026-10-30',clientName:'Client',applyIVA:true,
    lines:[{productId:null,description:'Servicio',quantity:1,unitPrice:'0.00'}]}).success);
  assert.equal(budgetSchema.safeParse({budgetDate:'2026-02-30',clientName:'Client',applyIVA:true,lines:[]}).success,false);
});
