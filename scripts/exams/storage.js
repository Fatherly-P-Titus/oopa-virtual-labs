/* Local-first persistence for the OOPA examination foundation.
 * IndexedDB is preferred; localStorage is a fallback for file/local preview environments.
 * This is not a security boundary and does not synchronize between devices.
 */
(function (root) {
  'use strict';
  const Schema = root.OOPAExamSchema;
  if (!Schema) throw new Error('Load scripts/exams/schema.js before storage.js');
  const DB_NAME = 'oopa-examination-data';
  const DB_VERSION = 1;
  const STORE_NAME = 'records';
  const FALLBACK_KEY = 'oopa.exams.local.v1';
  let dbPromise = null;
  let forceFallback = false;
  function remoteEnabled() { return !!(root.OOPABackend && root.OOPABackend.enabled && root.OOPABackend.enabled()); }
  function remoteClient() {
    const client = root.OOPABackend && root.OOPABackend.requireClient ? root.OOPABackend.requireClient() : null;
    if (!client) throw new Error('Supabase backend is not configured.');
    return client;
  }
  async function remoteList(collection) {
    if (!Schema.COLLECTIONS.includes(collection)) throw new Error('Unknown collection: ' + collection);
    const { data, error } = await remoteClient().from('oopa_records').select('payload').eq('collection', collection);
    if (error) throw new Error('Backend read failed: ' + error.message);
    return (data || []).map(row => clone(row.payload));
  }

  function clone(value) { return value == null ? value : JSON.parse(JSON.stringify(value)); }
  function localAvailable() { try { return !!root.localStorage; } catch (_) { return false; } }
  function readFallback() {
    if (!localAvailable()) throw new Error('No local storage is available in this browser context');
    try { return JSON.parse(root.localStorage.getItem(FALLBACK_KEY) || '{"schemaVersion":1,"records":[]}'); }
    catch (_) { throw new Error('Local examination data could not be read; export/recovery is required before continuing'); }
  }
  function writeFallback(state) {
    if (!localAvailable()) throw new Error('No local storage is available in this browser context');
    try { root.localStorage.setItem(FALLBACK_KEY, JSON.stringify(state)); }
    catch (_) { throw new Error('Local storage could not save this record (storage may be full or blocked)'); }
  }
  function openDb() {
    if (forceFallback || !root.indexedDB) return Promise.resolve(null);
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      let request;
      try { request = root.indexedDB.open(DB_NAME, DB_VERSION); } catch (e) { reject(e); return; }
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, { keyPath: 'key' });
          store.createIndex('collection', 'collection', { unique: false });
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error || new Error('IndexedDB open failed'));
      request.onblocked = () => reject(new Error('IndexedDB upgrade is blocked by another open OOPA tab'));
    }).catch(() => { forceFallback = true; return null; });
    return dbPromise;
  }
  function idbRequest(request) {
    return new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error || new Error('IndexedDB request failed'));
    });
  }
  function withStore(mode, operation) {
    return openDb().then(db => {
      if (!db) return null;
      return new Promise((resolve, reject) => {
        let tx;
        try { tx = db.transaction(STORE_NAME, mode); } catch (e) { reject(e); return; }
        const store = tx.objectStore(STORE_NAME);
        let result;
        try { result = operation(store); } catch (e) { try { tx.abort(); } catch (_) {} reject(e); return; }
        tx.oncomplete = () => resolve(result && result.__request ? result.__request.result : result);
        tx.onerror = () => reject(tx.error || new Error('IndexedDB transaction failed'));
        tx.onabort = () => reject(tx.error || new Error('IndexedDB transaction aborted'));
      });
    });
  }
  async function list(collection) {
    if (remoteEnabled()) return remoteList(collection);
    if (!Schema.COLLECTIONS.includes(collection)) throw new Error('Unknown collection: ' + collection);
    const db = await openDb();
    if (!db) return readFallback().records.filter(r => r.collection === collection).map(r => clone(r.data));
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const request = tx.objectStore(STORE_NAME).index('collection').getAll(collection);
      request.onsuccess = () => resolve(request.result.map(r => clone(r.data)));
      request.onerror = () => reject(request.error || new Error('Could not list records'));
    });
  }
  async function get(collection, id) {
    if (remoteEnabled()) {
      if (!Schema.COLLECTIONS.includes(collection)) throw new Error('Unknown collection: ' + collection);
      const { data, error } = await remoteClient().from('oopa_records').select('payload').eq('collection', collection).eq('record_id', id).maybeSingle();
      if (error) throw new Error('Backend read failed: ' + error.message); return data ? clone(data.payload) : null;
    }
    const db = await openDb();
    if (!db) {
      const row = readFallback().records.find(r => r.collection === collection && r.id === id);
      return row ? clone(row.data) : null;
    }
    const row = await withStore('readonly', store => ({ __request: store.get(collection + ':' + id) }));
    return row ? clone(row.data) : null;
  }
  async function put(collection, input) {
    const record = Schema.validateRecord(collection, input);
    if (remoteEnabled()) {
      const { error } = await remoteClient().from('oopa_records').upsert({ collection, record_id: record.id, payload: record, updated_at: new Date().toISOString() }, { onConflict: 'collection,record_id' });
      if (error) throw new Error('Backend save failed: ' + error.message); return clone(record);
    }
    const key = collection + ':' + record.id;
    const db = await openDb();
    if (!db) {
      const state = readFallback();
      const index = state.records.findIndex(r => r.key === key);
      const row = { key, collection, id: record.id, data: clone(record) };
      if (index >= 0) state.records[index] = row; else state.records.push(row);
      writeFallback(state);
    } else {
      await withStore('readwrite', store => store.put({ key, collection, id: record.id, data: clone(record) }));
    }
    return clone(record);
  }
  async function remove(collection, id) {
    if (remoteEnabled()) {
      if (!Schema.COLLECTIONS.includes(collection)) throw new Error('Unknown collection: ' + collection);
      const { error } = await remoteClient().from('oopa_records').delete().eq('collection', collection).eq('record_id', id);
      if (error) throw new Error('Backend delete failed: ' + error.message); return true;
    }
    if (!Schema.COLLECTIONS.includes(collection)) throw new Error('Unknown collection: ' + collection);
    const key = collection + ':' + id;
    const db = await openDb();
    if (!db) {
      const state = readFallback();
      const before = state.records.length;
      state.records = state.records.filter(r => r.key !== key);
      writeFallback(state);
      return before !== state.records.length;
    }
    await withStore('readwrite', store => store.delete(key));
    return true;
  }
  async function appendAudit(event) { return put('auditEvents', event || Schema.makeAuditEvent('system', 'storage.audit', 'system', null)); }
  async function exportBackup() {
    const data = {};
    for (const collection of Schema.COLLECTIONS) data[collection] = await list(collection);
    return { format: 'oopa-examination-backup', schemaVersion: Schema.SCHEMA_VERSION, exportedAt: new Date().toISOString(), data };
  }
  async function importBackup(backup, options) {
    options = options || {};
    if (remoteEnabled()) throw new Error('Browser-side restore is disabled for the connected backend. Use the administrator server-side restore procedure documented in docs/backend/MILESTONE-7.md.');
    if (!backup || backup.format !== 'oopa-examination-backup' || !Number.isInteger(backup.schemaVersion) || !backup.data) throw new Error('This file is not a valid OOPA examination backup');
    if (backup.schemaVersion > Schema.SCHEMA_VERSION) throw new Error('Backup was created by a newer schema version');
    const prepared = [];
    for (const collection of Schema.COLLECTIONS) {
      // Milestone 1 backups used schema v1 and predate the administrators collection.
      const sourceRecords = Array.isArray(backup.data[collection]) ? backup.data[collection]
        : (collection === 'administrators' && backup.schemaVersion === 1 ? [] : null);
      if (!sourceRecords) throw new Error('Backup is missing collection: ' + collection);
      for (const record of sourceRecords) {
        const normalized = Schema.validateRecord(collection, record);
        // Validation may normalize fields; preserve source timestamps for faithful backup restoration.
        if (record.createdAt) normalized.createdAt = record.createdAt;
        if (record.updatedAt) normalized.updatedAt = record.updatedAt;
        prepared.push({ key: collection + ':' + normalized.id, collection, id: normalized.id, data: clone(normalized) });
      }
    }
    if (options.replace === true) {
      const db = await openDb();
      if (!db) {
        // Single localStorage write: replacement is all-or-nothing at the storage API level.
        writeFallback({ schemaVersion: Schema.SCHEMA_VERSION, records: prepared });
      } else {
        await new Promise((resolve, reject) => {
          let tx;
          try { tx = db.transaction(STORE_NAME, 'readwrite'); } catch (e) { reject(e); return; }
          const store = tx.objectStore(STORE_NAME);
          store.clear();
          prepared.forEach(row => store.put(row));
          tx.oncomplete = resolve;
          tx.onerror = () => reject(tx.error || new Error('Backup replacement transaction failed'));
          tx.onabort = () => reject(tx.error || new Error('Backup replacement transaction aborted'));
        });
      }
    } else {
      for (const row of prepared) {
        const db = await openDb();
        if (!db) {
          const state = readFallback(); const index = state.records.findIndex(r => r.key === row.key);
          if (index >= 0) state.records[index] = row; else state.records.push(row);
          writeFallback(state);
        } else await withStore('readwrite', store => store.put(row));
      }
    }
    await appendAudit(Schema.makeAuditEvent(options.actorId || 'system', 'backup.import', 'backup', null, 'success', { replace: options.replace === true, schemaVersion: backup.schemaVersion }));
    return { imported: Schema.COLLECTIONS.reduce((sum, name) => sum + (Array.isArray(backup.data[name]) ? backup.data[name].length : 0), 0), schemaVersion: Schema.SCHEMA_VERSION };
  }
  function downloadBackup(backup, filename) {
    if (!root.Blob || !root.URL || !root.document) throw new Error('File downloads are unavailable in this environment');
    const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
    const url = root.URL.createObjectURL(blob);
    const a = root.document.createElement('a'); a.href = url; a.download = filename || ('oopa-exam-backup-' + new Date().toISOString().slice(0,10) + '.json');
    root.document.body.appendChild(a); a.click(); a.remove(); root.URL.revokeObjectURL(url);
  }
  async function health() {
    if (remoteEnabled()) {
      try { const { error } = await remoteClient().from('oopa_profiles').select('auth_user_id').limit(1); if (error) throw error; return { backend: 'Supabase / PostgreSQL', persistent: true, sharedAcrossDevices: true, warning: 'Remote database is configured. Server-side policies must be validated before real examinations.' }; }
      catch (e) { return { backend: 'Supabase (connection error)', persistent: false, sharedAcrossDevices: true, warning: e.message || 'Backend connection failed.' }; }
    }
    const db = await openDb();
    if (db) return { backend: 'IndexedDB', persistent: true, sharedAcrossDevices: false, warning: 'Browser-local data is not synchronized and is not tamper-proof.' };
    try { readFallback(); return { backend: 'localStorage', persistent: true, sharedAcrossDevices: false, warning: 'Fallback storage has tighter size limits and is not tamper-proof.' }; }
    catch (e) { return { backend: 'unavailable', persistent: false, sharedAcrossDevices: false, warning: e.message }; }
  }
  root.OOPAExamStorage = Object.freeze({ list, get, put, remove, appendAudit, exportBackup, importBackup, downloadBackup, health, constants: Object.freeze({ DB_NAME, DB_VERSION, FALLBACK_KEY }) });
  if (typeof module !== 'undefined' && module.exports) module.exports = root.OOPAExamStorage;
})(typeof globalThis !== 'undefined' ? globalThis : this);
