// Checks the configured Auth service without printing passwords, API keys or tokens.
// The optional signup check deletes only the temporary account it creates.
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { randomBytes } = require('node:crypto');

async function main() {
  const config = JSON.parse(readFileSync(resolve(__dirname, '../android/app/google-services.json'), 'utf8'));
  if (config.project_info.project_id !== 'arjunlayover') {
    throw new Error('Expected the arjunlayover Firebase project. No request was sent.');
  }
  const client = config.client.find((entry) => entry.client_info.android_client_info.package_name === 'com.app');
  if (!client) throw new Error('The configured Android client was not found.');
  const apiKey = client.api_key[0].current_key;
  async function request(action, body) {
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(25000),
    });
    const result = await response.json();
    if (!response.ok) {
      // Whitelist the service error code; never print request data or raw responses.
      const code = /^[A-Z_]+/.exec(result.error?.message ?? '')?.[0] ?? 'AUTH_REQUEST_FAILED';
      throw new Error(code);
    }
    return result;
  }
  const email = `routerescue-qa-${randomBytes(12).toString('hex')}@example.invalid`;
  const password = `${randomBytes(24).toString('base64url')}aA9!`;
  if (!process.argv.includes('--create-test-account')) {
    try {
      await request('signInWithPassword', { email, password, returnSecureToken: true });
      throw new Error('Unexpected sign-in result.');
    } catch (error) {
      if (!['INVALID_LOGIN_CREDENTIALS', 'EMAIL_NOT_FOUND'].includes(error.message)) throw error;
      console.log('PASS: arjunlayover Auth is reachable and rejects nonexistent credentials.');
      console.log('Use --create-test-account to test signup and login with a temporary account.');
    }
    return;
  }

  let testToken;
  let testUid;
  try {
    const created = await request('signUp', { email, password, returnSecureToken: true });
    testToken = created.idToken;
    testUid = created.localId;
    console.log('PASS: Firebase created a temporary email/password account.');
    const signedIn = await request('signInWithPassword', { email, password, returnSecureToken: true });
    if (signedIn.localId !== testUid) throw new Error('The signed-in user did not match the test account.');
    testToken = signedIn.idToken;
    console.log('PASS: Firebase signed in with the newly created credentials.');
    try {
      await request('signInWithPassword', { email, password: `${password}wrong`, returnSecureToken: true });
      throw new Error('Firebase unexpectedly accepted an incorrect password.');
    } catch (error) {
      if (!['INVALID_LOGIN_CREDENTIALS', 'INVALID_PASSWORD'].includes(error.message)) throw error;
      console.log('PASS: Firebase rejected an incorrect password.');
    }
  } finally {
    if (testToken) {
      try {
        await request('delete', { idToken: testToken });
        console.log('PASS: Temporary test account deleted. No Firestore records or email messages were created.');
      } catch (error) {
        throw new Error(`Test account cleanup failed (${error.message}); remove only Auth UID ${testUid} in the Firebase console.`);
      }
    }
  }
}

main().catch((error) => {
  console.error(`Firebase Auth check failed: ${error.message}`);
  process.exitCode = 1;
});
