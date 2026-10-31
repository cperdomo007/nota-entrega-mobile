// Business clock, independent from the container/phone timezone.
export function documentNumber(date = new Date(), timeZone = process.env.DOCUMENT_TIME_ZONE || 'America/Caracas') {
  const parts = new Intl.DateTimeFormat('en-GB', {timeZone,day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date);
  const values = Object.fromEntries(parts.map(p=>[p.type,p.value]));
  return `${values.day}${values.month}${values.year}${values.hour}${values.minute}`;
}
