-- Add status column to teams for 3-state management: pending, approved, rejected
alter table public.teams add column if not exists status text default 'pending' check (status in ('pending', 'approved', 'rejected'));

-- Backfill: existing approved teams get status = 'approved', rest stay 'pending'
update public.teams set status = 'approved' where is_approved = true;
update public.teams set status = 'pending' where is_approved = false;
