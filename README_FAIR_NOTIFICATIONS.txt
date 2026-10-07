TAPID CAREER FAIR VISIBILITY AND NOTIFICATIONS

1. Run ALL of tapid_fair_notifications.sql in Supabase > SQL Editor.
   Existing accounts and fairs are preserved. Already-published upcoming fairs
   are included, so you do not need to delete and recreate your test fair.

2. Upload and commit these three website files together:
   dashboard.html
   employer-dashboard.html
   fair-dashboard.js

   Suggested commit: Fix career fair visibility and event reminders

WHAT CHANGES
Published university fairs appear on the student Home and Career Fairs pages,
including fairs whose employer list has not yet been added.
Company lists use the university's managed import roster plus legacy approved lists.
An imported company without a TapID account is still shown by name. Students can
request a connection only when that company has a verified recruiter at their school.
Requests use the fair ID so dates and event identity stay attached to the right fair.
School matching recognizes the existing Cal Poly name variants.

Employers see upcoming fairs for which the university listed their company,
plus an event notification. This is a university listing, not a separate booking
or proof that the employer has confirmed attendance.
Draft fairs stay hidden from students and employers.

Students receive a publication alert and reminders during the week before,
the day before, and the event day. Reminders use America/Los_Angeles calendar days.
If a dashboard first opens close to an event, it gets the current reminder rather
than every missed reminder. Existing read reminders are not made unread again.
Changing the event time creates a fresh set of reminders for that new schedule.
Notification preferences are respected.

Mark All Read removes the visible student notification list and its badge.
It saves read status instead of deleting notification history. A later reminder
is a separate notification and appears normally.
Employers can mark event alerts read separately from message/follow-up tasks.
Open dashboards refresh their event state once per minute and when focused.
Background refresh does not overwrite recruiter or student opportunity form edits.

BACKGROUND REMINDERS
The SQL attempts to enable pg_cron and schedule an hourly reminder job.
If Supabase shows a warning that the job was not scheduled, enable pg_cron in
Supabase > Integrations > Cron, then run tapid_fair_reminder_schedule.sql.
Without that job, reminders are still created when either dashboard loads or
refreshes; the job creates them even while everyone is logged out.
These are TapID dashboard notifications, not email or browser push messages.

CHECK AFTER DEPLOYMENT
Create a fair as a draft: it should stay hidden.
Publish it: its students should see the fair and notification. List an existing
company using the company selector: its verified recruiter should see the fair
and listing notification. It may take up to one minute on an already-open page.
Mark student notifications read: the list should clear and stay clear on refresh.
For reminder testing, change the date to tomorrow: a separate reminder appears.
Confirm a published fair with no roster still shows up for students.
Check an imported company without an account appears with connection unavailable.

VALIDATION
All local test suites passed, including unread clearing, new reminder display,
empty published fairs, HTML escaping, Pacific date formatting, shared roster
wiring and scoped fair request wiring. SQL and live Supabase notifications must
be checked after you run the migration; no authenticated database connection
was available in this workspace.

Official scheduling reference:
https://supabase.com/docs/guides/cron/quickstart
