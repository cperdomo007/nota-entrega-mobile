import { digest } from './security.js';
import { validateLines, toCents, toMoney } from './validation.js';

const tables = {clients:'clients',products:'products',notes:'delivery_notes',budgets:'budgets'};
export const editFailure = (status,code) => Object.assign(new Error(code),{status,publicCode:code});

// The version is derived from persisted data; no schema migration is needed.
export async function readEntity(db,kind,id,lock=false) {
  const table=tables[kind];
  if (!table) throw editFailure(404,'NOT_FOUND');
  const [[record]]=await db.execute(`SELECT * FROM ${table} WHERE id=?${lock?' FOR UPDATE':''}`,[id]);
  if (!record) throw editFailure(404,'NOT_FOUND');
  let lines=[], serials=[];
  if (kind==='notes') {
    [lines]=await db.execute('SELECT l.*,p.name AS productName,p.unit,p.hasSerial FROM note_lines l LEFT JOIN products p ON p.id=l.productId WHERE l.noteId=? ORDER BY l.id',[id]);
    [serials]=await db.execute('SELECT s.lineId,s.serial FROM serials s JOIN note_lines l ON l.id=s.lineId WHERE l.noteId=? ORDER BY s.id',[id]);
  } else if (kind==='budgets') {
    [lines]=await db.execute('SELECT * FROM budget_lines WHERE budgetId=? ORDER BY id',[id]);
  }
  const version=digest(JSON.stringify({record,lines,serials}));
  return {record,version,json:{...record,_version:version,
    ...('hasSerial' in record?{hasSerial:!!record.hasSerial}:{}),
    ...('applyIVA' in record?{applyIVA:!!record.applyIVA}:{}),
    ...(['notes','budgets'].includes(kind)?{lines:lines.map(l=>({...l,
      ...(kind==='notes'?{hasSerial:!!l.hasSerial,serials:serials.filter(s=>s.lineId===l.id).map(s=>s.serial)}:{})}))}:{})}};
}

export async function updateEntity(db,kind,id,input) {
  const current=await readEntity(db,kind,id,true);
  if (current.version!==input._version) throw editFailure(409,'EDIT_CONFLICT');
  if (kind==='clients') {
    await db.execute('UPDATE clients SET name=?,rif=?,address=?,phone=?,email=?,contact=? WHERE id=?',
      [input.name,input.rif||null,input.address||null,input.phone||null,input.email||null,input.contact||null,id]);
  } else if (kind==='products') {
    await db.execute('UPDATE products SET name=?,barcode=?,description=?,category=?,price=?,unit=?,hasSerial=?,stock=? WHERE id=?',
      [input.name,input.barcode||null,input.description||null,input.category||null,toMoney(toCents(input.price)),input.unit,input.hasSerial,input.stock,id]);
  } else {
    const ids=[...new Set(input.lines.map(l=>l.productId).filter(Boolean))];
    const [products]=ids.length?await db.query(`SELECT id,hasSerial FROM products WHERE id IN (${ids.map(()=>'?').join(',')})`,ids):[[]];
    if (kind==='notes' ? !validateLines(input.lines,products) : products.length!==ids.length) throw editFailure(422,'INVALID_LINES');
    const [[config]]=await db.query('SELECT ivaRate FROM company_config ORDER BY id LIMIT 1');
    const rate=Number(config?.ivaRate??16);
    if (!Number.isFinite(rate)||rate<0||rate>100) throw editFailure(503,'INVALID_TAX');
    if (input.ivaRate!==undefined && Number(input.ivaRate)!==rate) throw editFailure(409,'IVA_CHANGED');
    const subtotal=input.lines.reduce((sum,l)=>sum+toCents(l.unitPrice)*l.quantity,0);
    const iva=input.applyIVA?Math.round(subtotal*rate/100):0;
    if (subtotal+iva>999999999999) throw editFailure(422,'INVALID_AMOUNT');
    const values=[input[kind==='notes'?'noteDate':'budgetDate'],input.clientName,input.clientRif||null,
      input.clientAddress||null,input.clientPhone||null,input.clientContact||null,toMoney(subtotal),input.applyIVA,
      toMoney(iva),toMoney(subtotal+iva),input.observations||null];
    if (kind==='notes') {
      await db.execute('UPDATE delivery_notes SET noteDate=?,clientName=?,clientRif=?,clientAddress=?,clientPhone=?,clientContact=?,subtotal=?,applyIVA=?,ivaAmount=?,total=?,observations=?,deliveredBy=?,receivedBy=? WHERE id=?',
        [...values,input.deliveredBy||null,input.receivedBy||null,id]);
      await db.execute('DELETE s FROM serials s JOIN note_lines l ON l.id=s.lineId WHERE l.noteId=?',[id]);
      await db.execute('DELETE FROM note_lines WHERE noteId=?',[id]);
      for (const line of input.lines) {
        const [created]=await db.execute('INSERT INTO note_lines (noteId,productId,quantity,unitPrice,lineTotal) VALUES (?,?,?,?,?)',
          [id,line.productId,line.quantity,toMoney(toCents(line.unitPrice)),toMoney(toCents(line.unitPrice)*line.quantity)]);
        for (const serial of line.serials) await db.execute('INSERT INTO serials (lineId,serial) VALUES (?,?)',[created.insertId,serial]);
      }
    } else {
      await db.execute('UPDATE budgets SET budgetDate=?,clientName=?,clientRif=?,clientAddress=?,clientPhone=?,clientContact=?,subtotal=?,applyIVA=?,ivaAmount=?,total=?,observations=? WHERE id=?',[...values,id]);
      await db.execute('DELETE FROM budget_lines WHERE budgetId=?',[id]);
      for (const line of input.lines) await db.execute('INSERT INTO budget_lines (budgetId,productId,description,quantity,unitPrice,lineTotal) VALUES (?,?,?,?,?,?)',
        [id,line.productId||null,line.description,line.quantity,toMoney(toCents(line.unitPrice)),toMoney(toCents(line.unitPrice)*line.quantity)]);
    }
  }
  return {id};
}
