/* Revalidate the account when a card is issued, not only when the page opens. */
async function requireUniversityCardAccess(expectedUserId) {
  const current = await tapid.getUser();
  if (!current) throw new Error('Your university session has expired. Sign in through University again.');
  if (expectedUserId && current.id !== expectedUserId) {
    throw new Error('The university account changed after this page opened. Sign in through University again to continue.');
  }
  if (sessionStorage.getItem('tapid-university-explicit-login') !== current.id) {
    throw new Error('Sign in through University to continue.');
  }
  const result = await tapid.client.from('university_admins').select('user_id,school_name,verification_status').eq('user_id',current.id).maybeSingle();
  if (result.error) throw result.error;
  if (!result.data || result.data.verification_status !== 'verified') {
    throw new Error('The signed-in account is not a verified university administrator. Sign in with your approved university email.');
  }
  if (!result.data.school_name?.trim()) throw new Error('Your university record needs a school name to continue.');
  return { user: current, admin: result.data };
}

function attachUniversitySessionNotice(expectedUserId) {
  return tapid.client.auth.onAuthStateChange((_event,session) => {
    if (session?.user?.id !== expectedUserId) {
      document.getElementById('issueCardBtn').disabled = true;
      tapid.setMessage(document.getElementById('message'),'Your university session changed. Sign in through University again before issuing cards.','error');
    }
  });
}
