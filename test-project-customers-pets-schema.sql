-- Reference schema for `customers`/`pets` matching LIVE exactly, reconstructed
-- from information_schema.columns + pg_constraint output pulled directly off the
-- live project (18 Aug 2026) — NOT meant to be run against live, where these
-- tables already exist. This is for (re)building a TEST project's tables so it's
-- an honest rehearsal environment, e.g. after discovering a test project was
-- built with an older/uncorrected script (see phase4-stays-table-LIVE.sql's
-- preflight check, added after hitting exactly this on the "Cocomomo-test
-- dashboard" project — its pets.id was uuid instead of text).
--
-- Run this on the TEST project only. It DROPS and recreates customers/pets there
-- (fine — test data only). RLS is not included here; check what policy live's
-- customers/pets tables actually use (see the RLS follow-up) and apply the same
-- to the test project separately.

drop table if exists pets;
drop table if exists customers;

create table customers (
  id text primary key,
  name text not null,
  ic_passport text,
  phone text,
  gender text,
  dob date,
  emergency_name text,
  emergency_phone text,
  customer_types jsonb not null default '[]'::jsonb,
  points_history jsonb not null default '[]'::jsonb,
  authorized_pickups jsonb not null default '[]'::jsonb,
  agreement jsonb,
  agreement_token text,
  color_override text,
  payments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table pets (
  id text primary key,
  customer_id text not null references customers(id) on delete cascade,
  name text not null,
  type text,
  breed text,
  colour text,
  gender text,
  dob date,
  boarding_size text,
  grooming_size text,
  spayed text,
  last_vax date,
  last_tick date,
  medical text,
  personality text,
  special text,
  risk_flags jsonb not null default '[]'::jsonb,
  photo text,
  stays jsonb not null default '[]'::jsonb,
  grooming_history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
