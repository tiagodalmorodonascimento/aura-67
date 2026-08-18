-- Aura 67: permite metas mínimas curtas e válidas, como "1" ou "10".
-- Execute depois da migration 016.

alter table public.behavior_plans
  drop constraint if exists behavior_plans_minimum_version_check;

alter table public.behavior_plans
  add constraint behavior_plans_minimum_version_check
  check (char_length(trim(minimum_version)) between 1 and 140);
