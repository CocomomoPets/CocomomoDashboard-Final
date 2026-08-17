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
-- RLS: matches the real policy on `customers`/`pets`, confirmed against live via
-- pg_policies (see the policy block below) — not a guess.

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

-- RLS — confirmed 18 Aug 2026 via pg_policies against live: `customers` and
-- `pets` each carry one ALL-command policy, qual/with_check both `true`, scoped
-- to the {authenticated} role (not anon) — named "Authenticated users can do
-- everything on <table>". Matched exactly here rather than guessed.
alter table stays enable row level security;
drop policy if exists "Authenticated users can do everything on stays" on stays;
create policy "Authenticated users can do everything on stays" on stays
  for all to authenticated using (true) with check (true);
