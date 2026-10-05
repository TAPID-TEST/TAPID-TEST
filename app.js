(function () {
  'use strict';

  if (!window.TAPID_CONFIG || !window.supabase) {
    throw new Error('TapID configuration or Supabase library failed to load.');
  }

  const client = window.supabase.createClient(
    window.TAPID_CONFIG.SUPABASE_URL,
    window.TAPID_CONFIG.SUPABASE_KEY,
    {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      }
    }
  );

  const platforms = {
    linkedin: { label: 'LinkedIn', icon: 'fa-brands fa-linkedin-in', className: 'social-linkedin' },
    instagram: { label: 'Instagram', icon: 'fa-brands fa-instagram', className: 'social-instagram' },
    github: { label: 'GitHub', icon: 'fa-brands fa-github', className: 'social-github' },
    tiktok: { label: 'TikTok', icon: 'fa-brands fa-tiktok', className: 'social-tiktok' },
    youtube: { label: 'YouTube', icon: 'fa-brands fa-youtube', className: 'social-youtube' },
    x: { label: 'X', icon: 'fa-brands fa-x-twitter', className: 'social-x' },
    twitter: { label: 'X', icon: 'fa-brands fa-x-twitter', className: 'social-x' },
    facebook: { label: 'Facebook', icon: 'fa-brands fa-facebook-f', className: 'social-facebook' },
    website: { label: 'Website', icon: 'fa-solid fa-globe', className: 'social-website' },
    portfolio: { label: 'Portfolio', icon: 'fa-solid fa-briefcase', className: 'social-portfolio' },
    other: { label: 'Link', icon: 'fa-solid fa-link', className: 'social-other' }
  };

  window.tapid = {
    client,

    async getUser() {
      const { data, error } = await client.auth.getUser();
      if (error) return null;
      return data.user || null;
    },

    async requireUser() {
      const user = await this.getUser();
      if (!user) {
        const next = encodeURIComponent(window.location.pathname + window.location.search);
        window.location.replace(`login.html?next=${next}`);
        return null;
      }
      return user;
    },

    async getProfileById(id) {
      const { data, error } = await client.from('profiles').select('*').eq('id', id).maybeSingle();
      if (error) throw error;
      return data;
    },

    async getProfileByUsername(username) {
      const { data, error } = await client.from('profiles').select('*').eq('username', username).maybeSingle();
      if (error) throw error;
      return data;
    },

    onboardingComplete(profile) {
      if (!profile) return false;
      if (profile.onboarding_complete === true) return true;
      return Boolean(profile.first_name && profile.last_name && profile.username && profile.school && profile.major && profile.school_year && profile.graduation_year);
    },

    cardActivated(profile) {
      return Boolean(profile && profile.card_activated === true);
    },

    cleanUsername(value) {
      return String(value || '').trim().toLowerCase().replace(/[^a-z0-9._-]/g, '').replace(/^[._-]+|[._-]+$/g, '');
    },

    normalizeUrl(value) {
      const raw = String(value || '').trim();
      if (!raw) return '';
      if (/^https?:\/\//i.test(raw)) return raw;
      return `https://${raw}`;
    },

    siteUrl(path = '') {
      const configured = String(window.TAPID_CONFIG.SITE_URL || '').replace(/\/$/, '');
      const base = configured || window.location.origin;
      const cleanPath = String(path || '').replace(/^\//, '');
      return cleanPath ? `${base}/${cleanPath}` : base;
    },

    profileUrl(username) {
      return this.siteUrl(`profile.html?u=${encodeURIComponent(username)}`);
    },

    // Backward-compatible name used by earlier dashboard builds.
    publicProfileUrl(username) {
      return this.profileUrl(username);
    },

    async signedFileUrl(bucket, path, expiresIn = 3600) {
      if (!bucket || !path) return '';
      const { data, error } = await client.storage.from(bucket).createSignedUrl(path, expiresIn);
      if (error) throw error;
      return data?.signedUrl || '';
    },

    platformMeta(platform) {
      const key = String(platform || 'other').trim().toLowerCase();
      return platforms[key] || { ...platforms.other, label: platform || 'Link' };
    },

    setMessage(element, message, type = 'info') {
      if (!element) return;
      element.textContent = message || '';
      element.className = `message ${type}`;
      element.hidden = !message;
    },

    setBusy(button, busy, busyText = 'Working…') {
      if (!button) return;
      if (busy) {
        button.dataset.originalText = button.textContent;
        button.textContent = busyText;
        button.disabled = true;
      } else {
        button.textContent = button.dataset.originalText || button.textContent;
        button.disabled = false;
      }
    },

    friendlyAuthError(error) {
      const raw = (error && error.message) ? error.message : 'Something went wrong.';
      const msg = raw.toLowerCase();
      if (msg.includes('user already registered')) return 'An account already exists for that email. Try logging in.';
      if (msg.includes('duplicate') || msg.includes('unique') || msg.includes('database error saving new user')) return 'That TapID username may already be taken. Try a different username.';
      return raw;
    },

    downloadVCard(profile, contact, links) {
      const name = [profile.first_name, profile.last_name].filter(Boolean).join(' ');
      const notes = [profile.major, profile.school, profile.school_year, profile.graduation_year ? `Class of ${profile.graduation_year}` : null].filter(Boolean).join(' | ');
      const linkedin = (links || []).find(link => String(link.platform).toLowerCase() === 'linkedin');
      const lines = [
        'BEGIN:VCARD',
        'VERSION:3.0',
        `FN:${this.escapeVCard(name)}`,
        `N:${this.escapeVCard(profile.last_name || '')};${this.escapeVCard(profile.first_name || '')};;;`
      ];
      if (contact && contact.email) lines.push(`EMAIL;TYPE=INTERNET:${this.escapeVCard(contact.email)}`);
      if (contact && contact.phone) lines.push(`TEL;TYPE=CELL:${this.escapeVCard(contact.phone)}`);
      if (contact && contact.website) lines.push(`URL:${this.escapeVCard(contact.website)}`);
      lines.push(`URL:${this.escapeVCard(this.profileUrl(profile.username))}`);
      if (linkedin) lines.push(`X-SOCIALPROFILE;TYPE=linkedin:${this.escapeVCard(linkedin.url)}`);
      if (notes) lines.push(`NOTE:${this.escapeVCard(notes)}`);
      lines.push('END:VCARD');

      const blob = new Blob([lines.join('\r\n')], { type: 'text/vcard;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${(profile.first_name || 'tapid').toLowerCase()}-${(profile.last_name || 'contact').toLowerCase()}.vcf`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    },

    escapeVCard(value) {
      return String(value || '').replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/;/g, '\\;').replace(/,/g, '\\,');
    }
  };
})();
