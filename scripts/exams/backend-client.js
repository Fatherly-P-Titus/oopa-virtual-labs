/* Optional Supabase browser client. The anon key is public; database RLS is mandatory. */
(function(root){
  'use strict';
  const cfg=root.OOPABackendConfig||{};
  const enabled=cfg.provider==='supabase' && cfg.mode==='supabase' && /^https:\/\//.test(cfg.url||'') && String(cfg.anonKey||'').length>20;
  let client=null;
  if(enabled){
    if(!root.supabase||typeof root.supabase.createClient!=='function') throw new Error('Supabase JS failed to load. Check the CDN/network connection.');
    client=root.supabase.createClient(cfg.url,cfg.anonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  }
  root.OOPABackend=Object.freeze({
    enabled:()=>enabled,
    client:()=>client,
    config:()=>({provider:cfg.provider||'none',mode:enabled?'supabase':'local',configured:enabled}),
    requireClient:()=>{if(!enabled||!client)throw new Error('The OOPA backend is not configured. Use local prototype mode or configure Supabase as described in docs/backend/MILESTONE-7.md.');return client;},
    functionUrl:(name)=>{if(!enabled)throw new Error('Supabase backend is not configured.');return String(cfg.url).replace(/\/$/,'')+'/functions/v1/'+name;}
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
