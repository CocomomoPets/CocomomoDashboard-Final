-- Manual, direct restore of `stays` from `pets.stays` — run on LIVE.
-- Bypasses the dashboard's JS migration entirely (which appears to be failing
-- silently client-side, cause still being investigated) and does the same
-- backfill server-side instead. Safe to run more than once: skips any pet that
-- already has at least one row in `stays`, and ON CONFLICT DO NOTHING guards
-- against re-inserting the same stay id twice.

insert into stays (
  id, pet_id, check_in, check_out, status, checked_in, checked_in_pets, notes,
  custom_rate, custom_rate_mode, charges, pets, dropoff, pickup, paid_through, reminders_sent
)
select
  stay->>'id' as id,
  p.id as pet_id,
  (stay->>'checkIn')::date as check_in,
  (stay->>'checkOut')::date as check_out,
  coalesce(stay->>'status', 'Active') as status,
  coalesce((stay->>'checkedIn')::boolean, false) as checked_in,
  coalesce(stay->'checkedInPets', '[]'::jsonb) as checked_in_pets,
  coalesce(stay->>'notes', '') as notes,
  nullif(stay->>'customRate','')::numeric as custom_rate,
  coalesce(stay->>'customRateMode', 'flat') as custom_rate_mode,
  coalesce(stay->'charges', '[]'::jsonb) as charges,
  coalesce(stay->'pets', '[]'::jsonb) as pets,
  stay->'dropoff' as dropoff,
  stay->'pickup' as pickup,
  nullif(stay->>'paidThrough','')::date as paid_through,
  coalesce(stay->'remindersSent', '{"checkin":[],"checkout":[]}'::jsonb) as reminders_sent
from pets p, jsonb_array_elements(p.stays) as stay
where jsonb_array_length(p.stays) > 0
  and p.id not in (select distinct pet_id from stays)
  and stay->>'id' is not null
on conflict (id) do nothing;

-- Verify afterward:
select count(*) from stays;
