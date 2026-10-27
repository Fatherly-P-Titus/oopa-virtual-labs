$(async function () {
  $('#current-year').text(new Date().getFullYear());
  const session = OOPALocalAuth.currentSession();
  if (!session) { location.replace('admin-login.html'); return; }
  const user = session.user, isAdmin = user.role === 'overall-admin';
  const hubs = [
    { id:'physics', name:'Physics' }, { id:'chemistry', name:'Chemistry' }, { id:'biology', name:'Biology' },
    { id:'mathematics', name:'Mathematics' }, { id:'engineering', name:'Engineering' }
  ];
  const labs = OOPAExamLabRegistry.getAll();
  if (OOPABackend && OOPABackend.enabled() && isAdmin) { $('#instructor-username').attr('type','email').attr('placeholder','ada.okafor@institution.edu'); $('label[for="instructor-username"]').text('Instructor email'); $('#instructor-username').attr('maxlength','254'); $('#instructor-password').attr('minlength','12'); }
  const $accountMessage = $('#account-message');
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
  function msg($node, text, ok) { $node.toggleClass('success', !!ok).text(text); }
  $('#sidebar-name').text(user.displayName); $('#sidebar-role').text(isAdmin ? 'Overall Admin' : 'Instructor'); $('#user-avatar').text((user.displayName || user.username).charAt(0).toUpperCase());
  $('#welcome-title').text('Welcome, ' + user.displayName); $('#stat-role').text(isAdmin ? 'Overall Admin' : 'Instructor');
  if (!isAdmin) {
    $('#page-title').text('Instructor workspace'); $('#page-subtitle').text('Your assigned laboratory access and account settings.');
    $('#instructors-nav,#instructors,#permissions').hide(); $('#admin-only-content').hide(); $('#instructor-readonly').prop('hidden', false);
    const assigned = hubs.filter(h => (user.allowedHubs || []).includes(h.id)).map(h => h.name);
    const assignedLabs = labs.filter(l => (user.allowedLabs || []).includes(l.id)).map(l => l.name);
    $('#my-permissions').text('Assigned hubs: ' + (assigned.join(', ') || 'None') + '. Specific lab grants: ' + (assignedLabs.join(', ') || 'None') + '.');
    $('#stat-instructors').text('—');
  } else {
    $('#stat-instructors').text('…');
    $('#hub-permissions').html(hubs.map(h => `<label class="check-option"><input type="checkbox" name="hub-permission" value="${h.id}"> ${h.name}</label>`).join(''));
    $('#lab-permissions').html(labs.map(l => `<label class="check-option"><input type="checkbox" name="lab-permission" value="${l.id}"> <span>${esc(l.name)}<small>${esc(l.hubName)}</small></span></label>`).join(''));
    $('#hub-summary').html(hubs.map(h => `<article><b>${h.name}</b><span>${labs.filter(l=>l.hubId===h.id).length} registered labs</span></article>`).join(''));
    await refreshAccounts();
  }
  if (user.mustChangePassword) {
    $('#welcome-description').text('Your passphrase must be changed before continuing.');
    $('#instructors,#permissions').hide(); $('#security').addClass('force-change');
    $('#current-password').closest('.form-grid').find('#current-password').trigger('focus');
    $('#security')[0].scrollIntoView({behavior:'smooth',block:'start'});
  }
  async function refreshAccounts() {
    const accounts = (await OOPALocalAuth.listAccounts()).filter(a=>a.role==='instructor').sort((a,b)=>String(a.displayName).localeCompare(String(b.displayName)));
    $('#stat-instructors').text(accounts.length);
    $('#instructor-rows').html(accounts.length ? accounts.map(a => {
      const hubNames = hubs.filter(h => (a.allowedHubs||[]).includes(h.id)).map(h=>h.name);
      const labNames = labs.filter(l => (a.allowedLabs||[]).includes(l.id)).map(l=>l.name);
      const perms = hubNames.concat(labNames).join(', ') || 'No hubs/labs assigned';
      return `<tr><td><b>${esc(a.displayName)}</b></td><td>${esc(a.username)}</td><td>${esc(perms)}</td><td><span class="account-status ${a.active===false?'inactive':'active'}">${a.active===false?'Inactive':'Active'}</span>${a.mustChangePassword?'<small class="needs-change">Must change passphrase</small>':''}</td><td class="actions"><button type="button" data-edit="${esc(a.id)}">Edit</button><button type="button" data-toggle="${esc(a.id)}" data-active="${a.active===false?'1':'0'}">${a.active===false?'Activate':'Deactivate'}</button></td></tr>`;
    }).join('') : '<tr><td colspan="5">No instructor accounts yet. Create the first account above.</td></tr>');
  }
  function resetForm() {
    $('#instructor-form')[0].reset(); $('#instructor-id').val(''); $('#instructor-active').prop('checked', true);
    $('#save-instructor').text('Create instructor'); $('#cancel-edit').prop('hidden', true); $('#instructor-password').prop('required', true).val('');
    $('input[name="hub-permission"],input[name="lab-permission"]').prop('checked', false);
  }
  $('#cancel-edit').on('click', resetForm);
  $('#instructor-form').on('submit', async function(e) {
    e.preventDefault();
    try {
      const id = $('#instructor-id').val() || null;
      const result = await OOPALocalAuth.saveInstructor({ id, displayName:$('#instructor-name').val(), username:$('#instructor-username').val(), password:$('#instructor-password').val(), active:$('#instructor-active').prop('checked'), allowedHubs:$('input[name="hub-permission"]:checked').map((_,x)=>x.value).get(), allowedLabs:$('input[name="lab-permission"]:checked').map((_,x)=>x.value).get() });
      msg($accountMessage, (id?'Updated ':'Created ') + result.displayName + '. ' + (result.mustChangePassword?'They must change the passphrase at first sign-in.':''), true); resetForm(); await refreshAccounts();
    } catch(err) { msg($accountMessage, err.message || 'Could not save instructor.'); }
  });
  $('#instructor-rows').on('click','button[data-edit]', async function() {
    const a = (await OOPALocalAuth.listAccounts()).find(x=>x.id===$(this).data('edit')&&x.role==='instructor'); if (!a) return;
    $('#instructor-id').val(a.id); $('#instructor-name').val(a.displayName); $('#instructor-username').val(a.username); $('#instructor-password').val('').prop('required', false); $('#instructor-active').prop('checked', a.active !== false);
    $('input[name="hub-permission"]').each((_,x)=>$(x).prop('checked',(a.allowedHubs||[]).includes(x.value)));
    $('input[name="lab-permission"]').each((_,x)=>$(x).prop('checked',(a.allowedLabs||[]).includes(x.value)));
    $('#save-instructor').text('Save instructor'); $('#cancel-edit').prop('hidden', false); msg($accountMessage,'Editing '+a.displayName+'. Leave passphrase blank to keep it.'); $('#instructor-form')[0].scrollIntoView({behavior:'smooth',block:'start'});
  });
  $('#instructor-rows').on('click','button[data-toggle]', async function() {
    try { await OOPALocalAuth.setInstructorActive($(this).data('toggle'), $(this).data('active') === '1'); await refreshAccounts(); msg($accountMessage,'Instructor account status updated.',true); }
    catch(e) { msg($accountMessage,e.message || 'Could not update status.'); }
  });
  $('#password-form').on('submit', async function(e) {
    e.preventDefault();
    try {
      const next = $('#new-password').val(); if (next !== $('#confirm-password').val()) throw new Error('New passphrases do not match.');
      const updated = await OOPALocalAuth.changePassword($('#current-password').val(), next);
      msg($('#password-message'),'Passphrase updated successfully.',true); $('#password-form')[0].reset();
      if (updated.mustChangePassword) throw new Error('Please change your passphrase before continuing.');
      $('#welcome-description').text('Your account is ready.');
    } catch(e2) { msg($('#password-message'),e2.message || 'Could not update passphrase.'); }
  });
  $('#logout-button').on('click', async function() { await OOPALocalAuth.logout(); location.replace('admin-login.html'); });
});
