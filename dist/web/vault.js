/* AES-GCM, non-extractable origin-bound key. Same-origin XSS remains a threat. */
(() => {
  const open=()=>new Promise((resolve,reject)=>{const r=indexedDB.open('buscador-protected-v1',1);r.onupgradeneeded=()=>r.result.createObjectStore('vault');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  const get=(db,key)=>new Promise((resolve,reject)=>{const r=db.transaction('vault').objectStore('vault').get(key);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  const put=(db,key,value)=>new Promise((resolve,reject)=>{const t=db.transaction('vault','readwrite');t.objectStore('vault').put(value,key);t.oncomplete=resolve;t.onerror=()=>reject(t.error);});
  window.buscadorVault={
    async read(){const db=await open();try{const data=await get(db,'snapshot');if(!data)return null;const key=await get(db,'key');if(!key)throw Error('Missing protected key');return new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:data.iv},key,data.cipher));}finally{db.close();}},
    async write(value){const db=await open();try{let key=await get(db,'key');if(!key){key=await crypto.subtle.generateKey({name:'AES-GCM',length:256},false,['encrypt','decrypt']);await put(db,'key',key);}const iv=crypto.getRandomValues(new Uint8Array(12));const cipher=await crypto.subtle.encrypt({name:'AES-GCM',iv},key,new TextEncoder().encode(value));await put(db,'snapshot',{iv,cipher});}finally{db.close();}},
    async clear(){const db=await open();try{await new Promise((resolve,reject)=>{const t=db.transaction('vault','readwrite');t.objectStore('vault').clear();t.oncomplete=resolve;t.onerror=()=>reject(t.error);});}finally{db.close();}},
    async export(content){const url=URL.createObjectURL(new Blob([content],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='buscador-meus-registros.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),30000);}
  };
})();
