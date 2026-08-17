-- Cocomomo Dashboard — DB migration Phase 4: Stays table
-- Pain point #18 ("single growing JSON blob, no archiving plan"), next area after
-- Staff & leave (phase1-staff-tables.sql) and Customers & Pets
-- (phase2-customers-pets-tables-LIVE.sql).
--
-- Pulls `stays` out of the `pets.stays` JSONB column into its own table. The
-- `pets.stays` column is left in place and simply stops being written/read once the
-- matching CocomomoDashboard-Final.html update is deployed — no ALTER/DROP needed
-- on the existing `pets` table.
--
-- IMPORTANT — run this on a second/free Supabase test project FIRST, same as the
-- Staff and Customers/Pets phases were tested, before running it against live.
-- Once you do run it against live, run it BEFORE uploading the matching
-- CocomomoDashboard-Final.html — uploading the dashboard first means every save
-- fails until the table exists, not just stay-related saves.
--
-- RLS: copy whatever policy shape your existing `staff` / `customers` / `pets`
-- tables already use in the Supabase dashboard — this file can't see your project,
-- so the policy below is a best-guess placeholder matching a typical single-workspace
-- setup where the app's anon key needs full read/write. Replace it with your real
-- policy (or delete these two lines and set it up identically to the other tables
-- via the dashboard) before running against live.

create table if not exists stays (
  id text primary key,
  pet_id text not null references pets(id) on delete cascade,
  check_in date not null,
  check_out date not null,
  status text not null default 'Active',
  checked_in boolean not null default false,
  checked_in_pets jsonb not null default '[]',
  notes text default '',
  custom_rate numeric,
  custom_rate_mode text default 'flat',
  charges jsonb not null default '[]',
  pets jsonb not null default '[]',
  dropoff jsonb,
  pickup jsonb,
  paid_through date,
  reminders_sent jsonb not null default '{"checkin":[],"checkout":[]}',
  created_at timestamptz not null default now()
);

create index if not exists stays_pet_id_idx on stays(pet_id);

-- Placeholder RLS — verify against your other tables' actual policy before running
-- on live. If your other tables don't use RLS at all (relying solely on the anon
-- key being unguessable), skip these two lines to match.
alter table stays enable row level security;
drop policy if exists "allow anon full access" on stays;
create policy "allow anon full access" on stays
  for all using (true) with check (true);
