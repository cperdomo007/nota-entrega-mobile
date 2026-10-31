import { z } from 'zod';
export const emailSchema = z.string().trim().toLowerCase().email().max(254).regex(/^[\x21-\x7e]+$/);
export const loginSchema = z.object({ email: emailSchema, password: z.string().min(1).max(128) }).strict();
export const userSchema = z.object({ email: emailSchema, name: z.string().trim().min(1).max(100),
  password: z.string().min(12).max(128), role: z.enum(['user','admin']).default('user') }).strict();
export const moneySchema = z.union([z.string().regex(/^\d{1,8}(\.\d{1,2})?$/),
  z.number().finite().nonnegative().max(99999999.99).refine(n => Number.isInteger(Math.round(n * 1000000) / 10000))]);
export const toCents = value => Math.round(Number(value) * 100);
export const toMoney = cents => (cents / 100).toFixed(2);
const optional = max => z.string().trim().max(max).optional().default('');
export const noteSchema = z.object({
  // Accepted for old APKs, but numbering is assigned by the server on save.
  noteNumber: z.string().trim().min(1).max(50).optional(),
  noteDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(s => {
    const date = new Date(`${s}T00:00:00Z`); return !isNaN(date) && date.toISOString().slice(0,10) === s;
  }),
  clientName: z.string().trim().min(1).max(500), clientRif: optional(50), clientAddress: optional(2000),
  clientPhone: optional(20), clientContact: optional(100), applyIVA: z.boolean(),
  ivaRate: z.union([z.string(),z.number()]).optional(), observations: optional(5000),
  deliveredBy: optional(100), receivedBy: optional(100),
  lines: z.array(z.object({ productId: z.number().int().positive(),
    quantity: z.number().int().min(1).max(1000000), unitPrice: moneySchema,
    serials: z.array(z.string().trim().min(1).max(255)).max(1000).default([]) }).strict()).min(1).max(200)
}).strict();
export const clientSchema = z.object({
  name: z.string().trim().min(1).max(500), rif: optional(50), address: optional(2000),
  phone: optional(20), contact: optional(100),
  email: z.union([z.literal(''),z.string().trim().email().max(255)]).optional().default(''),
}).strict();
export const productSchema = z.object({
  name: z.string().trim().min(1).max(500), barcode: optional(255), description: optional(4000), category: optional(100),
  price: moneySchema.refine(value=>toCents(value)>0), unit: z.string().trim().min(1).max(50).default('UN'),
  hasSerial: z.boolean().default(false), stock: z.number().int().min(0).max(2147483647).default(0),
}).strict();
export const budgetSchema = noteSchema.omit({noteNumber:true,noteDate:true,deliveredBy:true,receivedBy:true,lines:true}).extend({
  budgetDate: noteSchema.shape.noteDate,
  lines: z.array(z.object({productId:z.number().int().positive().nullable().optional(),
    description:z.string().trim().min(1).max(4000),quantity:z.number().int().min(1).max(1000000),unitPrice:moneySchema}).strict()).min(1).max(200),
}).strict();
export function validateLines(lines, products) {
  const seen = new Set();
  let subtotal = 0;
  for (const line of lines) {
    const product = products.find(p => p.id === line.productId);
    if (!product || (product.hasSerial && line.serials.length !== line.quantity)) return false;
    for (const serial of line.serials) { if (seen.has(serial)) return false; seen.add(serial); }
    subtotal += toCents(line.unitPrice) * line.quantity;
    if (!Number.isSafeInteger(subtotal) || subtotal > 999999999999) return false;
  }
  return true;
}
