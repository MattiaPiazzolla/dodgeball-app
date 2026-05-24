alter table public.matches
  add column if not exists bracket_position int;
