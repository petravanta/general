/* ===== Drive store: petravanta's apps =====
   Canonical copy: https://github.com/petravanta/general/blob/main/shared/drive-store.js (see STANDARDS.md, "Data lives in Google Drive").
   Keeps an app's data in one JSON file in the user's Google Drive (drive.file scope: the app only sees files it created).
   The browser keeps only sign-in details, and a copy of changes that haven't reached Drive yet (for example while offline);
   that copy is deleted as soon as Drive has it. */
function DriveStore(o){
  // o: {clientId, file:'App data.json', app:'app-id', key:'localStorage prefix', empty:()=>data, merge:(remote,local)=>data, onChange:()=>{}}
  const API='https://www.googleapis.com', SCOPE='https://www.googleapis.com/auth/drive.file';
  const get=k=>{try{return JSON.parse(localStorage.getItem(o.key+'.'+k)||'null')}catch(e){return null}};
  const put=(k,v)=>{try{v==null?localStorage.removeItem(o.key+'.'+k):localStorage.setItem(o.key+'.'+k,JSON.stringify(v));return true}catch(e){return false}};
  const S={token:null,exp:0,fileId:get('file'),known:!!get('known'),data:null,busy:false,err:null,last:null,timer:null,ask:0};
  const t=get('token'); if(t&&t.exp>Date.now()){S.token=t.token;S.exp=t.exp}
  const live=()=>!!S.token&&Date.now()<S.exp;
  const note=()=>{try{o.onChange&&o.onChange()}catch(e){}};
  function gis(){return new Promise((res,rej)=>{
    if(window.google&&google.accounts&&google.accounts.oauth2) return res();
    const s=document.createElement('script'); s.src='https://accounts.google.com/gsi/client'; s.onload=res; s.onerror=()=>rej({code:'offline'}); document.head.appendChild(s)})}
  // Asking for a token opens Google's window, so call this from a tap. For an account that already agreed, the window closes by itself.
  function signIn(){return new Promise(async(res,rej)=>{
    try{await gis()}catch(e){return rej(e)}
    google.accounts.oauth2.initTokenClient({client_id:o.clientId,scope:SCOPE,error_callback:rej,
      callback:r=>{if(r.error) return rej(r); S.token=r.access_token; S.exp=Date.now()+(Number(r.expires_in||3600)-60)*1000; put('token',{token:S.token,exp:S.exp}); S.known=true; put('known',true); res()}
    }).requestAccessToken({prompt:S.known?'':'consent'});
  })}
  async function call(path,opt={}){
    if(!live()) throw {code:'expired'};
    let r; try{r=await fetch(API+path,{...opt,headers:{...(opt.headers||{}),Authorization:'Bearer '+S.token}})}catch(e){throw {code:'offline'}}
    if(r.status===401){S.token=null; put('token',null); throw {code:'expired'}}
    if(!r.ok) throw {code:'http',status:r.status};
    return r;
  }
  async function find(){
    if(S.fileId){try{const j=await (await call(`/drive/v3/files/${S.fileId}?fields=id,trashed`)).json(); if(!j.trashed) return S.fileId}catch(e){if(e.code!=='http') throw e}}
    const q=encodeURIComponent(`name='${o.file.replace(/'/g,"\\'")}' and trashed=false`);
    const j=await (await call(`/drive/v3/files?q=${q}&orderBy=modifiedTime desc&fields=files(id)`)).json();
    S.fileId=j.files&&j.files[0]?j.files[0].id:null; put('file',S.fileId); return S.fileId;
  }
  async function read(){const id=await find(); return id?(await call(`/drive/v3/files/${id}?alt=media`)).json():null}
  async function write(data){
    const body=JSON.stringify({app:o.app,saved:new Date().toISOString(),...data}), id=await find();
    if(id){await call(`/upload/drive/v3/files/${id}?uploadType=media`,{method:'PATCH',headers:{'Content-Type':'application/json'},body});return}
    const b='b'+Math.random().toString(36).slice(2), meta=JSON.stringify({name:o.file,mimeType:'application/json'});
    const j=await (await call('/upload/drive/v3/files?uploadType=multipart&fields=id',{method:'POST',headers:{'Content-Type':'multipart/related; boundary='+b},
      body:`--${b}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${meta}\r\n--${b}\r\nContent-Type: application/json\r\n\r\n${body}\r\n--${b}--`})).json();
    S.fileId=j.id; put('file',j.id);
  }
  async function flush(){
    clearTimeout(S.timer); if(!S.data||S.busy) return;
    if(!live()){note();return}
    S.busy=true; note();
    try{await write(S.data); S.err=null; S.last=new Date(); put('pending',null)}
    catch(e){S.err=e.code==='expired'?null:e.code==='offline'?'offline':'error'}
    finally{S.busy=false; note()}
  }
  // Load: Drive's copy, merged with any changes this browser hadn't saved yet. Creates the file on first use.
  async function load(interactive){
    if(!live()){ if(!interactive) throw {code:'expired'}; await signIn() }
    S.busy=true; note();
    const pending=get('pending');
    try{
      const remote=await read();
      let data=remote?o.merge(remote,o.empty()):o.empty();
      if(pending) data=o.merge(pending,data);
      S.data=data; S.err=null; S.last=new Date();
      if(!remote||pending){await write(data); put('pending',null)}
      return data;
    }catch(e){
      // offline with unsaved changes: carry on from them; they go to Drive once the connection is back
      if(e.code==='offline'&&pending){S.data=o.merge(pending,o.empty()); S.err='offline'; return S.data}
      S.err=e.code==='offline'?'offline':e.code==='expired'?null:'error'; throw e;
    }finally{S.busy=false; note()}
  }
  // Pick up changes made on another device
  async function refresh(){
    if(!live()||S.busy||!S.data) return false;
    try{const r=await read(); if(!r) return false; const before=JSON.stringify(S.data); S.data=o.merge(r,S.data); return JSON.stringify(S.data)!==before}
    catch(e){return false}
  }
  function save(data){S.data=data; if(!put('pending',data)) {/* storage full or blocked: Drive still gets it */} clearTimeout(S.timer); S.timer=setTimeout(flush,1500); note()}
  function signOut(){
    if(S.token&&window.google&&google.accounts&&google.accounts.oauth2) google.accounts.oauth2.revoke(S.token,()=>{});
    S.token=null; S.data=null; ['token','known','file','pending'].forEach(k=>put(k,null)); S.known=false; note();
  }
  // Tokens last an hour. Renew on a tap when it is close to running out or gone, then save anything waiting.
  document.addEventListener('click',e=>{
    if(!o.clientId||!S.known||e.target.closest('[data-drive]')) return;
    if(S.exp-Date.now()>10*60000||Date.now()-S.ask<60000) return;
    S.ask=Date.now(); signIn().then(flush).catch(()=>note());
  },true);
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='hidden') flush()});
  window.addEventListener('online',()=>flush());
  function status(){
    if(!S.data) return '';
    if(S.busy) return 'Saving to Google Drive…';
    const waiting=!!get('pending');
    if(S.err==='offline') return 'Offline · changes save to Drive when you’re back online';
    if(S.err) return 'Couldn’t reach Google Drive · will retry';
    if(!live()) return waiting?'Tap anywhere to reconnect Google Drive':'Google Drive sign-in expired';
    if(waiting) return 'Saving to Google Drive…';
    return 'Saved to Google Drive'+(S.last?' · '+S.last.toLocaleTimeString([],{hour:'numeric',minute:'2-digit'}):'');
  }
  return {load,save,flush,refresh,signIn,signOut,status,live,
    get data(){return S.data}, get known(){return S.known}, get configured(){return !!o.clientId}, get file(){return o.file},
    get needsTap(){return !!S.data&&!live()}};
}
/* ===== end Drive store ===== */
