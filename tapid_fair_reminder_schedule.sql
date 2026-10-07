-- Run only if the main migration reports that Cron could not be enabled.
-- First enable pg_cron in Supabase > Integrations > Cron.
select cron.schedule(
 'tapid-career-fair-reminders',
 '0 * * * *',
 'select public.refresh_fair_notifications(null,null);'
);
