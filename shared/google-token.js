/* ===== Google sign-in shared by petravanta's apps =====
   Canonical copy: https://github.com/petravanta/general/blob/main/shared/google-token.js (see STANDARDS.md, "Staying connected to Google Drive").
   Every app lives on petravanta.github.io and uses the same OAuth client, so a Drive token one app gets works in all of them.
   This keeps that token where every app can see it (localStorage key petravanta.google), one per Google account, so
   reconnecting in one app reconnects them all, and an app only ever uses the token of the account it connected with.
   Google gives a static site no refresh token: a token lasts an hour, and getting a new one opens Google's window,
   which browsers only allow right after a tap. With the account's email as a hint, that window closes by itself. */
const GoogleToken=(()=>{
  const KEY='petravanta.google', SCOPE='https://www.googleapis.com/auth/drive.file';
  const read=()=>{try{return JSON.parse(localStorage.getItem(KEY)||'null')||{}}catch(e){return {}}};
  const write=v=>{try{localStorage.setItem(KEY,JSON.stringify(v))}catch(e){}};
  const subs=[];
  // Another tab or app on this site got a token: let this one pick it up without a tap
  window.addEventListener('storage',e=>{if(e.key===KEY) subs.forEach(f=>{try{f()}catch(_){}})});
  function gis(){return new Promise((res,rej)=>{
    if(window.google&&google.accounts&&google.accounts.oauth2) return res();
    const s=document.createElement('script'); s.src='https://accounts.google.com/gsi/client'; s.onload=res; s.onerror=()=>rej({code:'offline'}); document.head.appendChild(s)})}
  // A token for this account with time left on it, or null
  function get(email){const t=email&&(read().tokens||{})[email]; return t&&t.exp>Date.now()?t:null}
  // o: {clientId, hint:'email to suggest', prompt:'' | 'select_account' | 'consent'}. Call from a tap. Resolves {token, exp, email}.
  function request(o){return new Promise(async(res,rej)=>{
    try{await gis()}catch(e){return rej(e)}
    google.accounts.oauth2.initTokenClient({client_id:o.clientId,scope:SCOPE,login_hint:o.hint||undefined,error_callback:rej,
      callback:async r=>{
        if(r.error) return rej(r);
        const t={token:r.access_token,exp:Date.now()+(Number(r.expires_in||3600)-60)*1000};
        // Which account it is, so the token is filed under the right one
        let email='';
        try{const j=await (await fetch('https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)',{headers:{Authorization:'Bearer '+t.token}})).json(); email=(j.user&&j.user.emailAddress)||''}catch(e){}
        if(!email) email=o.hint||'';
        if(email){
          const v=read(), now=Date.now(); v.tokens=v.tokens||{};
          for(const k in v.tokens) if(!(v.tokens[k].exp>now)) delete v.tokens[k];
          v.tokens[email]=t; v.last=email; write(v);
        }
        res({...t,email});
      }
    }).requestAccessToken({prompt:o.prompt||''});
  })}
  // Signing out on this browser. Google's permission stays, since the other apps and devices still use it.
  function forget(email){const v=read(); if(v.tokens&&email) delete v.tokens[email]; write(v)}
  return {get,request,forget,gis,onChange:f=>subs.push(f),get lastEmail(){return read().last||''}};
})();
/* ===== end Google sign-in ===== */
