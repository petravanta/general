/* ===== Local day: petravanta's apps =====
   Canonical copy: https://github.com/petravanta/general/blob/main/shared/local-day.js (see STANDARDS.md, "Forms and dates").
   Dates people pick or log are days on their own calendar, saved as YYYY-MM-DD. Never use toISOString().slice(0,10)
   for that: it gives the UTC date, which in the evening west of Greenwich is already tomorrow.
     LocalDay.today()              today's local day, e.g. '2026-11-22'
     LocalDay.of(date)             the local day of a Date
     LocalDay.toDate('2026-11-22') a local Date at midnight on that day, for date arithmetic
   One object, so pasting it never clashes with an app's own localDay or today names. */
const LocalDay=(()=>{
  const p=n=>String(n).padStart(2,'0');
  const of=(d=new Date())=>`${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}`;
  const toDate=s=>{const [y,m,d]=String(s).split('-').map(Number);return new Date(y,(m||1)-1,d||1)};
  return {of,today:()=>of(),toDate};
})();
/* ===== end local day ===== */
