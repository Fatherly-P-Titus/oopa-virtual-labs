/* Supabase project settings. Safe to commit only the project URL and anon key.
 * Keep this empty until a project has been configured. NEVER put service_role here.
 */
(function(root){
  'use strict';
  const config = Object.freeze({
    provider: 'supabase',
    url: '',
    anonKey: '',
    mode: 'local' // change to 'supabase' only after applying the migration and provisioning accounts
  });
  root.OOPABackendConfig = config;
  if (typeof module !== 'undefined' && module.exports) module.exports = config;
})(typeof globalThis !== 'undefined' ? globalThis : this);
