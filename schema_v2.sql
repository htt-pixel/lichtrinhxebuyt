-- BusLine v2: hồ sơ khách hàng / tài xế. Chạy SAU schema.sql, trong SQL Editor.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text not null default '',
  phone text check (phone is null or phone ~ '^\+?[0-9 ]{8,15}$'),
  address text,
  license_no text,
  role text not null default 'customer' check (role in ('customer','driver')),
  bus_id bigint references public.buses(id) on delete set null,  -- chỉ admin gán
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "own or admin read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy "own or admin update" on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy "admin delete" on public.profiles for delete to authenticated
  using (public.is_admin());
-- Không có policy INSERT: hồ sơ chỉ được tạo bởi trigger bên dưới.

-- Người dùng thường không được tự đổi vai trò, xe được gán, email
create or replace function public.guard_profile() returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.id := old.id; new.email := old.email; new.role := old.role; new.bus_id := old.bus_id;
  end if;
  return new;
end $$;
create trigger guard_profile before update on public.profiles
  for each row execute function public.guard_profile();

-- Tự tạo hồ sơ khi có tài khoản mới (vai trò chỉ nhận customer hoặc driver)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, coalesce(left(new.raw_user_meta_data ->> 'full_name', 80), ''),
          case when new.raw_user_meta_data ->> 'role' = 'driver' then 'driver' else 'customer' end)
  on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Tạo hồ sơ cho tài khoản đã có (ví dụ tài khoản admin)
insert into public.profiles (id, email, full_name)
select id, email, '' from auth.users on conflict do nothing;

-- Tài xế được đổi TRẠNG THÁI các chuyến của xe mình được gán, không đổi gì khác
create policy "driver update own trips" on public.trips for update to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'driver'
                 and p.bus_id is not null and p.bus_id = trips.bus_id))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'driver'
                 and p.bus_id is not null and p.bus_id = trips.bus_id));

create or replace function public.guard_trip() returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.route_id := old.route_id; new.bus_id := old.bus_id;
    new.departure := old.departure; new.direction := old.direction;
  end if;
  return new;
end $$;
create trigger guard_trip before update on public.trips
  for each row execute function public.guard_trip();
