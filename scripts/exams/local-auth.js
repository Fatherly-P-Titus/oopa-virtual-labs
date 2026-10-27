/* Milestone 2 local prototype account service.
 * WARNING: browser-local authentication is not a production security boundary.
 * Do not use for real examinations until backed by server-side identity/authorization.
 */
(function (root) {
  'use strict';
  const Store = root.OOPAExamStorage;
  const Schema = root.OOPAExamSchema;
  const SESSION_KEY = 'oopa.local.session.v2';
  const BACKEND_SESSION_KEY = 'oopa.backend.session.v1';
  function backendEnabled() { return !!(root.OOPABackend && root.OOPABackend.enabled && root.OOPABackend.enabled()); }
  function backendClient() { return root.OOPABackend.requireClient(); }
  async function backendProfile() {
    const client = backendClient(); const { data: authData, error: authError } = await client.auth.getUser();
    if (authError || !authData.user) return null;
    const { data, error } = await client.from('oopa_profiles').select('*').eq('auth_user_id', authData.user.id).maybeSingle();
    if (error) throw new Error('Could not load account profile: ' + error.message);
    if (!data || !data.active) { await client.auth.signOut(); throw new Error('This account is inactive or has not been provisioned.'); }
    return { id:data.app_user_id, authUserId:data.auth_user_id, username:authData.user.email, displayName:data.display_name, role:data.role, active:data.active, mustChangePassword:!!(authData.user.user_metadata?.must_change_password||data.must_change_password), allowedHubs:data.allowed_hubs||[], allowedLabs:data.allowed_labs||[] };
  }
  const ITERATIONS = 210000;
  if (!Store || !Schema) throw new Error('Load schema.js and storage.js before local-auth.js');
  const encoder = new TextEncoder();
  function b64(bytes) { return btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(bytes)))); }
  function fromB64(value) { return Uint8Array.from(atob(value), c => c.charCodeAt(0)); }
  async function derive(password, salt, iterations) {
    if (!root.crypto || !root.crypto.subtle) throw new Error('Secure Web Crypto is unavailable. Open this site over HTTPS or localhost.');
    const key = await root.crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
    return root.crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations, hash: 'SHA-256' }, key, 256);
  }
  async function hashPassword(password) {
    if (typeof password !== 'string' || password.length < 10 || password.length > 200) throw new Error('Passphrase must be 10–200 characters.');
    const salt = root.crypto.getRandomValues(new Uint8Array(16));
    return 'pbkdf2-sha256:' + ITERATIONS + ':' + b64(salt) + ':' + b64(await derive(password, salt, ITERATIONS));
  }
  async function verifyPassword(password, encoded) {
    const parts = String(encoded || '').split(':');
    if (parts.length !== 4 || parts[0] !== 'pbkdf2-sha256') return false;
    const iterations = Number(parts[1]);
    if (!Number.isInteger(iterations) || iterations < 100000 || iterations > 1000000) return false;
    const actual = new Uint8Array(await derive(password, fromB64(parts[2]), iterations));
    const expected = fromB64(parts[3]);
    if (actual.length !== expected.length) return false;
    let diff = 0; for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i];
    return diff === 0;
  }
  function safeUser(record) {
    return { id: record.id, username: record.username, displayName: record.displayName, role: record.role,
      active: record.active !== false, mustChangePassword: !!record.mustChangePassword,
      allowedHubs: Array.isArray(record.allowedHubs) ? record.allowedHubs : [],
      allowedLabs: Array.isArray(record.allowedLabs) ? record.allowedLabs : [] };
  }
  async function listAccounts() {
    if (backendEnabled()) {
      const {data,error}=await backendClient().from('oopa_profiles').select('*').order('display_name');
      if(error) throw new Error('Could not load backend accounts: '+error.message);
      return (data||[]).map(p=>({id:p.app_user_id,authUserId:p.auth_user_id,username:p.email||'',displayName:p.display_name,role:p.role,active:p.active!==false,mustChangePassword:!!p.must_change_password,allowedHubs:p.allowed_hubs||[],allowedLabs:p.allowed_labs||[]}));
    }
    const admins = await Store.list('administrators');
    const instructors = await Store.list('instructors');
    return admins.map(safeUser).concat(instructors.map(safeUser));
  }
  // Fixed bootstrap identity for this local prototype. This is intentionally
  // replaceable by server-managed identity in the later authentication milestone.
  const BOOTSTRAP_ADMIN = Object.freeze({ username: 'AdminStaff/001', displayName: 'Admin001', password: '12346' });
  async function ensureBootstrapAdmin() {
    if (backendEnabled()) return;
    const admins = await Store.list('administrators');
    const existing = admins.find(a => String(a.username || '').toLowerCase() === BOOTSTRAP_ADMIN.username.toLowerCase());
    if (existing) return;
    // Hash the specified initial passcode without weakening the normal password
    // policy used for all user-created/reset credentials.
    const salt = root.crypto.getRandomValues(new Uint8Array(16));
    const passwordHash = 'pbkdf2-sha256:' + ITERATIONS + ':' + b64(salt) + ':' + b64(await derive(BOOTSTRAP_ADMIN.password, salt, ITERATIONS));
    const account = { id: 'admin001-bootstrap', username: BOOTSTRAP_ADMIN.username, displayName: BOOTSTRAP_ADMIN.displayName,
      role: 'overall-admin', active: true, passwordHash, mustChangePassword: false,
      allowedHubs: ['physics','chemistry','biology','mathematics','engineering'], allowedLabs: [],
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    await Store.put('administrators', account);
    await Store.appendAudit(Schema.makeAuditEvent(account.id, 'account.bootstrap', 'administrator', account.id, 'success', { username: account.username, source: 'fixed-prototype-bootstrap' }));
  }

  async function setupFirstAdmin(input) {
    if (backendEnabled()) throw new Error('In backend mode, create the first Auth user in Supabase and insert its Overall Admin profile as described in docs/backend/MILESTONE-7.md. Public first-admin setup is disabled.');
    if ((await Store.list('administrators')).length) throw new Error('Administrator setup has already been completed in this browser.');
    const username = String(input.username || '').trim();
    const displayName = String(input.displayName || '').trim();
    if (!/^[A-Za-z0-9._/-]{3,80}$/.test(username)) throw new Error('Username must be 3–80 letters, numbers, dots, underscores, slashes or hyphens.');
    if (!displayName || displayName.length > 120) throw new Error('Enter a display name (maximum 120 characters).');
    if ((await listAccounts()).some(a => a.username.toLowerCase() === username.toLowerCase())) throw new Error('That username is already in use.');
    const account = { id: Schema.makeId('admin'), username, displayName, role: 'overall-admin', active: true,
      passwordHash: await hashPassword(input.password), mustChangePassword: false, allowedHubs: ['physics','chemistry','biology','mathematics','engineering'], allowedLabs: [],
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    await Store.put('administrators', account);
    await Store.appendAudit(Schema.makeAuditEvent(account.id, 'account.bootstrap', 'administrator', account.id, 'success', { username }));
    return safeUser(account);
  }
  async function login(username, password) {
    if (backendEnabled()) {
      const email=String(username||'').trim().toLowerCase(); if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Enter your account email address in backend mode.');
      const client=backendClient(); const {error}=await client.auth.signInWithPassword({email,password:String(password||'')});
      if(error) throw new Error('Sign-in failed. Check your email and passphrase, or contact the administrator.');
      try { const user=await backendProfile(); if(!user) throw new Error('Account profile is missing. Contact the administrator.'); root.sessionStorage.setItem(BACKEND_SESSION_KEY,JSON.stringify({user,issuedAt:new Date().toISOString()})); await Store.appendAudit(Schema.makeAuditEvent(user.id,'auth.login','account',user.id,'success',{provider:'supabase'})); return user; } catch(e) { await client.auth.signOut(); throw e; }
    }
    await ensureBootstrapAdmin();
    const needle = String(username || '').trim().toLowerCase();
    const records = (await Store.list('administrators')).concat(await Store.list('instructors'));
    const account = records.find(a => String(a.username || '').toLowerCase() === needle);
    if (!account || account.active === false || !(await verifyPassword(String(password || ''), account.passwordHash))) {
      await Store.appendAudit(Schema.makeAuditEvent('anonymous', 'auth.login', 'account', null, 'failure', { username: needle.slice(0, 80) }));
      throw new Error('Incorrect username or passphrase, or this account is inactive.');
    }
    const session = { user: safeUser(account), issuedAt: new Date().toISOString(), nonce: Schema.makeId('session') };
    try { root.sessionStorage.setItem(SESSION_KEY, JSON.stringify(session)); } catch (_) { throw new Error('Session storage is unavailable in this browser.'); }
    await Store.appendAudit(Schema.makeAuditEvent(account.id, 'auth.login', 'account', account.id, 'success'));
    return session.user;
  }
  function currentSession() {
    try { const session = JSON.parse(root.sessionStorage.getItem(backendEnabled() ? BACKEND_SESSION_KEY : SESSION_KEY) || 'null'); return session && session.user ? session : null; } catch (_) { return null; }
  }
  async function changePassword(currentPassword, newPassword) {
    const session = currentSession(); if (!session) throw new Error('Please sign in again.');
    if (backendEnabled()) {
      if(typeof newPassword!=='string'||newPassword.length<12||newPassword.length>200) throw new Error('Passphrase must be 12–200 characters.');
      const client=backendClient(); const {data:authData}=await client.auth.getUser(); if(!authData.user?.email) throw new Error('Please sign in again.');
      const {error:verifyError}=await client.auth.signInWithPassword({email:authData.user.email,password:String(currentPassword||'')}); if(verifyError) throw new Error('Current passphrase is incorrect.');
      const {error}=await client.auth.updateUser({password:newPassword,user_metadata:{must_change_password:false}}); if(error) throw new Error('Could not update passphrase: '+error.message);
      const {error:profileUpdateError}=await client.rpc('oopa_clear_password_change_flag'); if(profileUpdateError) throw new Error('Passphrase changed but account flag could not be cleared: '+profileUpdateError.message);
      const user=await backendProfile(); root.sessionStorage.setItem(BACKEND_SESSION_KEY,JSON.stringify({user,issuedAt:session.issuedAt})); await Store.appendAudit(Schema.makeAuditEvent(user.id,'account.password-change','account',user.id,'success',{provider:'supabase'})); return user;
    }
    const collection = session.user.role === 'overall-admin' ? 'administrators' : 'instructors';
    const account = await Store.get(collection, session.user.id);
    if (!account || !(await verifyPassword(currentPassword, account.passwordHash))) throw new Error('Current passphrase is incorrect.');
    account.passwordHash = await hashPassword(newPassword); account.mustChangePassword = false;
    await Store.put(collection, account);
    session.user = safeUser(account); root.sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
    await Store.appendAudit(Schema.makeAuditEvent(account.id, 'account.password-change', 'account', account.id, 'success'));
    return session.user;
  }
  async function saveInstructor(input) {
    const session = currentSession(); if (!session || session.user.role !== 'overall-admin') throw new Error('Only the Overall Admin can manage instructor accounts.');
    if (backendEnabled()) {
      const client=backendClient(); const {data:{session:authSession}}=await client.auth.getSession(); if(!authSession) throw new Error('Please sign in again.');
      const payload={appUserId:input.id||Schema.makeId('instructor'),email:String(input.email||input.username||'').trim(),displayName:String(input.displayName||'').trim(),temporaryPassword:String(input.password||''),active:input.active!==false,allowedHubs:Array.isArray(input.allowedHubs)?input.allowedHubs:[],allowedLabs:Array.isArray(input.allowedLabs)?input.allowedLabs:[]};
      const response=await fetch(root.OOPABackend.functionUrl('admin-provision-instructor'),{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+authSession.access_token,'apikey':(root.OOPABackendConfig||{}).anonKey||''},body:JSON.stringify(payload)});
      const result=await response.json().catch(()=>({})); if(!response.ok) throw new Error(result.error||'Instructor provisioning failed.');
      return {id:result.appUserId,username:result.email,displayName:result.displayName,role:'instructor',active:true,allowedHubs:payload.allowedHubs,allowedLabs:payload.allowedLabs,mustChangePassword:true};
    }
    const username = String(input.username || '').trim(), displayName = String(input.displayName || '').trim();
    if (!/^[A-Za-z0-9._/-]{3,80}$/.test(username)) throw new Error('Username must be 3–80 letters, numbers, dots, underscores, slashes or hyphens.');
    if (!displayName || displayName.length > 120) throw new Error('Enter an instructor name (maximum 120 characters).');
    const all = await listAccounts(); if (all.some(a => a.id !== input.id && a.username.toLowerCase() === username.toLowerCase())) throw new Error('That username is already in use.');
    let account = input.id ? await Store.get('instructors', input.id) : null;
    if (input.id && !account) throw new Error('Instructor account not found.');
    const old = account && Object.assign({}, account);
    account = Object.assign({}, account || { id: Schema.makeId('instructor'), createdAt: new Date().toISOString(), role: 'instructor' }, {
      username, displayName, role: 'instructor', active: !!input.active,
      allowedHubs: Array.isArray(input.allowedHubs) ? input.allowedHubs : [],
      allowedLabs: Array.isArray(input.allowedLabs) ? input.allowedLabs : [], updatedAt: new Date().toISOString()
    });
    if (input.password) account.passwordHash = await hashPassword(input.password);
    else if (!account.passwordHash) throw new Error('Set an initial passphrase of at least 10 characters.');
    if (!old || input.password) account.mustChangePassword = true;
    await Store.put('instructors', account);
    await Store.appendAudit(Schema.makeAuditEvent(session.user.id, old ? 'instructor.update' : 'instructor.create', 'instructor', account.id, 'success', { username, active: account.active, allowedHubs: account.allowedHubs, allowedLabs: account.allowedLabs }));
    return safeUser(account);
  }
  async function setInstructorActive(id, active) {
    if (backendEnabled()) {
      const session=currentSession(); if(!session||session.user.role!=='overall-admin') throw new Error('Only the Overall Admin can manage instructor accounts.');
      const account=(await listAccounts()).find(a=>a.id===id); if(!account) throw new Error('Instructor not found.');
      const client=backendClient(); const {data:{session:authSession}}=await client.auth.getSession(); if(!authSession) throw new Error('Please sign in again.');
      const response=await fetch(root.OOPABackend.functionUrl('admin-provision-instructor'),{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+authSession.access_token,'apikey':(root.OOPABackendConfig||{}).anonKey||''},body:JSON.stringify({appUserId:id,email:account.username,displayName:account.displayName,active:!!active,allowedHubs:account.allowedHubs,allowedLabs:account.allowedLabs})}); const result=await response.json().catch(()=>({})); if(!response.ok) throw new Error(result.error||'Could not update instructor status.');
      await Store.appendAudit(Schema.makeAuditEvent(session.user.id,active?'instructor.activate':'instructor.deactivate','instructor',id,'success')); return;
    }
    const session = currentSession(); if (!session || session.user.role !== 'overall-admin') throw new Error('Only the Overall Admin can manage instructor accounts.');
    const account = await Store.get('instructors', id); if (!account) throw new Error('Instructor not found.');
    account.active = !!active; await Store.put('instructors', account);
    await Store.appendAudit(Schema.makeAuditEvent(session.user.id, active ? 'instructor.activate' : 'instructor.deactivate', 'instructor', id, 'success'));
  }
  async function logout() { const s = currentSession(); try { root.sessionStorage.removeItem(SESSION_KEY); root.sessionStorage.removeItem(BACKEND_SESSION_KEY); } catch (_) {} if (backendEnabled()) { try { await backendClient().auth.signOut(); } catch (_) {} } if (s) await Store.appendAudit(Schema.makeAuditEvent(s.user.id, 'auth.logout', 'account', s.user.id, 'success')); }
  root.OOPALocalAuth = Object.freeze({ hashPassword, verifyPassword, listAccounts, ensureBootstrapAdmin, setupFirstAdmin, login, currentSession, changePassword, saveInstructor, setInstructorActive, logout });
  if (typeof module !== 'undefined' && module.exports) module.exports = root.OOPALocalAuth;
})(typeof globalThis !== 'undefined' ? globalThis : this);
