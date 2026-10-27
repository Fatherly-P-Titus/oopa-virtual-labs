$(async function () {
  $('#current-year').text(new Date().getFullYear());
  const $message = $('#form-message');
  function message(text, success) { $message.toggleClass('success', !!success).text(text); }
  $('#auth-eyebrow').text('RESTRICTED ACCESS');
  $('#auth-title').text('Admin Login');
  $('#auth-intro').text('Sign in with your assigned administrator or instructor credentials.');
  $('#username-label').text('Staff ID / Username');
  $('#username').attr('type', 'text').attr('autocomplete', 'username').attr('placeholder', 'Enter Staff ID or username');
  $('#passcode-label').text('Passcode');
  $('#passcode').attr('autocomplete', 'current-password').attr('placeholder', 'Enter passcode');
  $('#submit-button').html('Sign in <span>→</span>');
  try {
    if (OOPABackend && OOPABackend.enabled()) {
      $('#auth-eyebrow').text('BACKEND AUTHENTICATION');
      $('#username-label').text('Email address');
      $('#username').attr('type', 'email').attr('placeholder', 'name@institution.edu');
      $('#passcode-label').text('Passphrase');
      $('#passcode').attr('placeholder', 'Enter passphrase');
      if (OOPALocalAuth.currentSession()) { location.replace('admin-page.html'); return; }
      message('Use the account provisioned for you by the administrator.', false);
    } else {
      await OOPALocalAuth.ensureBootstrapAdmin();
      if (OOPALocalAuth.currentSession()) { location.replace('admin-page.html'); return; }
      message('Sign in to continue. Contact the Overall Admin if you need an instructor account.', false);
    }
  } catch (e) { message(e.message || 'Unable to initialize sign-in.'); }
  $('#toggle-passcode').on('click', function () {
    const input = $('#passcode'); const show = input.attr('type') === 'password';
    input.attr('type', show ? 'text' : 'password'); $(this).text(show ? 'Hide' : 'Show');
  });
  $('#login-form').on('submit', async function (event) {
    event.preventDefault();
    const username = $('#username').val().trim(), password = $('#passcode').val();
    try {
      await OOPALocalAuth.login(username, password);
      message('Signed in. Opening management workspace…', true);
      window.setTimeout(() => { location.href = 'admin-page.html'; }, 250);
    } catch (e) { message(e.message || 'Sign in failed.'); $('#passcode').trigger('focus'); }
  });
});
