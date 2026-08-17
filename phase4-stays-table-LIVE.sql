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

-- Preflight: stays.pet_id below is a `text` foreign key into pets(id), matching
-- live's `pets` table (pet IDs are referenced elsewhere — e.g. a shared room's
-- "sharing with" list points at another pet's id directly — so they were
-- preserved as exact TEXT rather than replaced with auto-generated uuids, see
-- phase2-customers-pets-tables-LIVE.sql). If this project's `pets` table was
-- instead built with a `uuid` id (e.g. an older/uncorrected script run on a test
-- project), the CREATE TABLE below would fail on the FK with a confusing
-- "incompatible types: text and uuid" error. Catch that here with a clear
-- message instead: rebuild `pets`/`customers` on THIS project using the exact
-- same script that created them on live (on live, saved as "Create Customers &
-- Pets Tables (Text IDs)") before re-running this file.
do $$
declare
  pet_id_type text;
begin
  select data_type into pet_id_type
  from information_schema.columns
  where table_schema = 'public' and table_name = 'pets' and column_name = 'id';

  if pet_id_type is null then
    raise exception 'Preflight check failed: no "pets" table (or no "id" column) found on this project. Run the Customers & Pets migration script here first — the one saved as "Create Customers & Pets Tables (Text IDs)" on the live project — before running this file.';
  end if;

  if pet_id_type <> 'text' then
    raise exception 'Preflight check failed: pets.id on this project is type "%", not "text". stays.pet_id must match pets.id exactly. Rebuild pets/customers on this project using the same script that created them on live ("Create Customers & Pets Tables (Text IDs)") — do not just change the column type here, since existing pet IDs may already be wrong-typed/regenerated.', pet_id_type;
  end if;
end $$;

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
