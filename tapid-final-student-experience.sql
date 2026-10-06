begin;

alter table public.student_opportunity_preferences
  add column if not exists opportunity_statement text;

alter table public.student_opportunity_preferences
  drop constraint if exists student_opportunity_preferences_statement_length;

alter table public.student_opportunity_preferences
  add constraint student_opportunity_preferences_statement_length
  check (opportunity_statement is null or char_length(opportunity_statement) <= 600);

commit;
