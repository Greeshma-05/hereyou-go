import('./app.js').catch(() => {
  const message = document.getElementById('auth-message');
  message.textContent = 'Secure sign-in could not load. Check your internet connection and refresh this page.';
  message.classList.add('error');
  const button = document.getElementById('auth-submit');
  button.textContent = 'Refresh to try again';
  button.type = 'button';
  button.disabled = false;
  button.onclick = () => location.reload();
});
