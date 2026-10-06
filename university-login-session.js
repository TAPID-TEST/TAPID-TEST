/* University login always asks for credentials, even with a saved session. */
(() => {
  const button = document.getElementById('loginBtn');
  button.disabled = true;
  sessionStorage.removeItem('tapid-university-explicit-login');
  window.universityLoginReady = tapid.client.auth.signOut({ scope: 'local' })
    .then(({ error }) => {
      if (error) throw error;
      button.disabled = false;
    })
    .catch(error => {
      tapid.setMessage(document.getElementById('message'), 'Could not reset the previous session. Refresh this page to try again.', 'error');
      throw error;
    });
})();
