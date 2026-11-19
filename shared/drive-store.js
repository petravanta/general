/* ===== Drive store: petravanta's apps =====
   Canonical copy: https://github.com/petravanta/general/blob/main/shared/drive-store.js (see STANDARDS.md, "Data lives in Google Drive").
   Needs GoogleToken (shared/google-token.js) inlined above it.
   Keeps an app's data in one JSON file in the user's Google Drive, at petravanta/<App name>/<file> (drive.file scope: the apps
   only see files they created). A file saved before folders existed is moved there once, on the first connect.
   The browser keeps a copy of the last data, so the app opens straight away even when the hour-long Google sign-in has run out,
   and changes that haven't reached Drive yet (for example while offline). The first tap after that reconnects, merges with
   Drive's copy and saves. */
function DriveStore(o){
  // o: {clientId, file:'App data.json', folder:'App name' (default: file without ' data.json'), app:'app-id', key:'localStorage prefix', empty:()=>data, merge:(remote,local)=>data,
  //     onChange:()=>{}, onRemote:data=>{} (Drive's copy changed what the app shows)}
  const API='https://www.googleapis.com';
  const get=k=>{try{return JSON.parse(localStorage.getItem(o.key+'.'+k)||'null')}catch(e){return null}};
  const put=(k,v)=>{try{v==null?localStorage.removeItem(o.key+'.'+k):localStorage.setItem(o.key+'.'+k,JSON.stringify(v));return true}catch(e){return false}};
  const S={token:null,exp:0,email:get('email')||'',fileId:get('file'),folderId:get('folder'),known:!!get('known'),data:null,stale:false,busy:false,err:null,last:null,timer:null,ask:0};
  // The app's own token from before tokens were shared; good until it runs out
  const t=get('token'); if(t&&t.exp>Date.now()){S.token=t.token;S.exp=t.exp} put('token',null);
  if(S.known){const c=get('copy')||get('pending'); if(c){S.data=c; S.stale=true}}
  // Load Google's script now: if it only starts loading on the tap, the browser may block its window
  if(o.clientId&&S.known) GoogleToken.gis().catch(()=>{});
  const live=()=>{
    const g=GoogleToken.get(S.email); if(g&&g.exp>S.exp){S.token=g.token;S.exp=g.exp}
    return !!S.token&&Date.now()<S.exp;
  };
  const note=()=>{try{o.onChange&&o.onChange()}catch(e){}};
  // Opens Google's window, so call this from a tap. For an account that already agreed, the window closes by itself.
  // A first connect suggests the account the other apps use; after that, the account this app connected with.
  async function signIn(){
    const r=await GoogleToken.request({clientId:o.clientId,hint:S.email||(S.known?'':GoogleToken.lastEmail),prompt:S.known||GoogleToken.lastEmail?'':'consent'});
    S.token=r.token; S.exp=r.exp; S.known=true; put('known',true);
    if(r.email&&r.email!==S.email){S.email=r.email; put('email',r.email)}
  }
  async function call(path,opt={}){
    if(!live()) throw {code:'expired'};
    let r; try{r=await fetch(API+path,{...opt,headers:{...(opt.headers||{}),Authorization:'Bearer '+S.token}})}catch(e){throw {code:'offline'}}
    if(r.status===401){S.token=null; S.exp=0; GoogleToken.forget(S.email); throw {code:'expired'}}
    if(!r.ok) throw {code:'http',status:r.status};
    return r;
  }
  // Files live in petravanta/<App name>/ in the user's Drive (STANDARDS.md, "Where it lives").
  // Every app shares one OAuth client, so they all see the one petravanta folder whichever app made it.
  const ROOT='petravanta', SUB=o.folder||o.file.replace(/ data\.json$/i,'');
  const FOLDER='application/vnd.google-apps.folder', qs=v=>"'"+String(v).replace(/\\/g,'\\\\').replace(/'/g,"\\'")+"'";
  async function folder(name,parent){
    const q=encodeURIComponent(`name=${qs(name)} and mimeType='${FOLDER}' and ${qs(parent)} in parents and trashed=false`);
    const j=await (await call(`/drive/v3/files?q=${q}&orderBy=createdTime&fields=files(id)`)).json();
    if(j.files&&j.files[0]) return j.files[0].id; // two apps racing may make two; the oldest wins from then on
    return (await (await call('/drive/v3/files?fields=id',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({name,mimeType:FOLDER,parents:[parent]})})).json()).id;
  }
  async function home(){
    if(S.folderId) return S.folderId;
    S.folderId=await folder(SUB,await folder(ROOT,'root')); put('folder',S.folderId); return S.folderId;
  }
  // One-time move of a file saved before folders (in My Drive's root) into the app's folder. Moving keeps the file's id,
  // so other devices that remember it carry on.
  async function tidy(id){
    if(get('moved')===id) return;
    const dir=await home(), f=await (await call(`/drive/v3/files/${id}?fields=parents`)).json(), from=(f.parents||[]).filter(p=>p!==dir);
    if((f.parents||[]).indexOf(dir)<0) await call(`/drive/v3/files/${id}?addParents=${dir}`+(from.length?`&removeParents=${from.join(',')}`:'')+'&fields=id',
      {method:'PATCH',headers:{'Content-Type':'application/json'},body:'{}'});
    put('moved',id);
  }
  async function find(){
    if(S.fileId){try{const j=await (await call(`/drive/v3/files/${S.fileId}?fields=id,trashed`)).json(); if(!j.trashed){await tidy(S.fileId); return S.fileId}}catch(e){if(e.code!=='http') throw e}}
    const dir=await home(), name=`name=${qs(o.file)} and trashed=false`, list=async q=>
      (await (await call(`/drive/v3/files?q=${encodeURIComponent(q)}&orderBy=modifiedTime desc&fields=files(id)`)).json()).files||[];
    // The app's folder first, then anywhere else this app can see (a copy saved before folders)
    const hit=(await list(`${name} and ${qs(dir)} in parents`))[0]||(await list(name))[0];
    S.fileId=hit?hit.id:null; put('file',S.fileId); if(S.fileId) await tidy(S.fileId); return S.fileId;
  }
  async function read(){const id=await find(); return id?(await call(`/drive/v3/files/${id}?alt=media`)).json():null}
  async function write(data){
    const body=JSON.stringify({app:o.app,saved:new Date().toISOString(),...data}), id=await find();
    if(id){await call(`/upload/drive/v3/files/${id}?uploadType=media`,{method:'PATCH',headers:{'Content-Type':'application/json'},body});return}
    const b='b'+Math.random().toString(36).slice(2), meta=JSON.stringify({name:o.file,mimeType:'application/json',parents:[await home()]});
    const j=await (await call('/upload/drive/v3/files?uploadType=multipart&fields=id',{method:'POST',headers:{'Content-Type':'multipart/related; boundary='+b},
      body:`--${b}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${meta}\r\n--${b}\r\nContent-Type: application/json\r\n\r\n${body}\r\n--${b}--`})).json();
    S.fileId=j.id; put('file',j.id);
  }
  // Data opened from this browser's copy may be behind Drive's: merge Drive's in before writing over it
  async function catchUp(){
    if(!S.stale) return;
    const remote=await read(); S.stale=false;
    if(!remote) return;
    const before=JSON.stringify(S.data); S.data=o.merge(remote,S.data); put('copy',S.data);
    if(JSON.stringify(S.data)!==before) try{o.onRemote&&o.onRemote(S.data)}catch(e){}
  }
  async function flush(){
    clearTimeout(S.timer); if(!S.data||S.busy) return;
    if(!live()){note();return}
    S.busy=true; note();
    try{await catchUp(); await write(S.data); S.err=null; S.last=new Date(); put('pending',null)}
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
      S.data=data; S.stale=false; S.err=null; S.last=new Date(); put('copy',data);
      if(!remote||pending){await write(data); put('pending',null)}
      return data;
    }catch(e){
      // offline with unsaved changes: carry on from them; they go to Drive once the connection is back
      if(e.code==='offline'&&pending){S.data=o.merge(pending,o.empty()); S.stale=true; S.err='offline'; return S.data}
      S.err=e.code==='offline'?'offline':e.code==='expired'?null:'error'; throw e;
    }finally{S.busy=false; note()}
  }
  // Pick up changes made on another device
  async function refresh(){
    if(!live()||S.busy||!S.data) return false;
    try{const r=await read(); if(!r) return false; const before=JSON.stringify(S.data); S.data=o.merge(r,S.data); S.stale=false; put('copy',S.data); return JSON.stringify(S.data)!==before}
    catch(e){return false}
  }
  function save(data){S.data=data; put('copy',data); if(!put('pending',data)) {/* storage full or blocked: Drive still gets it */} clearTimeout(S.timer); S.timer=setTimeout(flush,1500); note()}
  function signOut(){
    GoogleToken.forget(S.email);
    S.token=null; S.exp=0; S.data=null; S.stale=false; S.email=''; ['known','file','folder','moved','pending','copy','email'].forEach(k=>put(k,null)); S.known=false; note();
  }
  // Tokens last an hour. Renew on a tap when it is close to running out or gone, then save anything waiting.
  document.addEventListener('click',e=>{
    if(!o.clientId||!S.known||e.target.closest('[data-drive]')) return;
    live(); if(S.exp-Date.now()>10*60000||Date.now()-S.ask<60000) return;
    S.ask=Date.now(); signIn().then(flush).catch(()=>note());
  },true);
  // Another app or tab reconnected this account: carry on with its token
  GoogleToken.onChange(()=>{if(S.known&&S.data&&live()) flush(); else note()});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='hidden') flush()});
  window.addEventListener('online',()=>flush());
  function status(){
    if(!S.data) return '';
    if(S.busy) return 'Saving to Google Drive…';
    const waiting=!!get('pending');
    if(S.err==='offline') return 'Offline · changes save to Drive when you’re back online';
    if(S.err) return 'Couldn’t reach Google Drive · will retry';
    if(!live()) return waiting?'Tap anywhere to save to Google Drive':'Tap anywhere to reconnect Google Drive';
    if(waiting) return 'Saving to Google Drive…';
    return 'Saved to Google Drive'+(S.last?' · '+S.last.toLocaleTimeString([],{hour:'numeric',minute:'2-digit'}):'');
  }
  // folder(): the id of petravanta/<App name>/, made if missing, for anything else the app saves to Drive (Google Docs, photos)
  return {load,save,flush,refresh,signIn,signOut,status,live,folder:home,
    get data(){return S.data}, get known(){return S.known}, get configured(){return !!o.clientId}, get file(){return o.file},
    get needsTap(){return !!S.data&&!live()}};
}
/* ===== end Drive store ===== */
