-- BusLine v3: loại xe (cố định / đón dọc đường), giá vé, độ trễ, đặt chỗ.
-- Chạy SAU schema.sql và schema_v2.sql, TRƯỚC các file seed_*.sql.

alter table public.routes
  add column service_type text not null default 'fixed' check (service_type in ('fixed','flag_down')),
  add column base_fare int not null default 6000 check (base_fare >= 0),
  add column per_km int not null default 0 check (per_km >= 0);   -- chỉ dùng cho xe đón dọc đường

alter table public.stops add column offset_min int not null default 0 check (offset_min >= 0);  -- phút kể từ điểm đầu
alter table public.trips add column delay_min int not null default 0 check (delay_min between 0 and 240);

create table public.bookings (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  trip_id bigint not null references public.trips(id) on delete cascade,
  board_stop_id bigint references public.stops(id) on delete set null,   -- tuyến cố định
  pickup_lat double precision, pickup_lng double precision,              -- xe đón dọc đường
  alight_stop_id bigint references public.stops(id) on delete set null,
  seats int not null default 1 check (seats between 1 and 5),
  fare int not null default 0,                                           -- do trigger tính
  pay_method text not null default 'cash' check (pay_method in ('cash','transfer','ewallet')),
  pay_status text not null default 'unpaid' check (pay_status in ('unpaid','paid')),
  note text check (note is null or length(note) <= 200),
  created_at timestamptz not null default now()
);
create index on public.bookings (user_id);
create index on public.bookings (trip_id);

create or replace function public.hav_km(a double precision, b double precision, c double precision, d double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(sin(radians(c - a) / 2) ^ 2 + cos(radians(a)) * cos(radians(c)) * sin(radians(d - b) / 2) ^ 2))
$$;

-- Giá vé và kiểm tra được tính ở server: người dùng không tự đặt giá được
create or replace function public.bookings_before() returns trigger
language plpgsql security definer set search_path = public as $$
declare t public.trips; r public.routes; bo public.stops; al public.stops; cap int; used int; km double precision;
begin
  select * into t from trips where id = new.trip_id;
  if not found then raise exception 'Chuyến không tồn tại.'; end if;
  if t.status in ('cancelled','done') then raise exception 'Chuyến này không còn nhận đặt chỗ.'; end if;
  select * into r from routes where id = t.route_id;
  select * into al from stops where id = new.alight_stop_id and route_id = t.route_id;
  if not found then raise exception 'Điểm xuống không thuộc tuyến này.'; end if;
  if r.service_type = 'fixed' then
    select * into bo from stops where id = new.board_stop_id and route_id = t.route_id;
    if not found then raise exception 'Điểm lên không thuộc tuyến này.'; end if;
    if (t.direction = 'di' and bo.seq >= al.seq) or (t.direction = 've' and bo.seq <= al.seq) then
      raise exception 'Điểm xuống phải nằm sau điểm lên theo hướng chạy của chuyến.';
    end if;
    new.pickup_lat := null; new.pickup_lng := null;
    new.fare := r.base_fare * new.seats;
  else
    if new.pickup_lat is null or new.pickup_lng is null or al.lat is null then
      raise exception 'Cần chọn điểm đón trên bản đồ.';
    end if;
    new.board_stop_id := null;
    km := public.hav_km(new.pickup_lat, new.pickup_lng, al.lat, al.lng) * 1.3;   -- hệ số đường vòng
    new.fare := round(((r.base_fare + r.per_km * km) / 500)::numeric) * 500 * new.seats;
  end if;
  if t.bus_id is not null then
    select capacity into cap from buses where id = t.bus_id;
    select coalesce(sum(seats), 0) into used from bookings where trip_id = t.id;
    if used + new.seats > cap then raise exception 'Chuyến này đã hết chỗ.'; end if;
  end if;
  new.user_id := coalesce(auth.uid(), new.user_id);
  new.pay_status := 'unpaid';
  return new;
end $$;
create trigger bookings_before before insert on public.bookings
  for each row execute function public.bookings_before();

alter table public.bookings enable row level security;
create policy "insert own" on public.bookings for insert to authenticated
  with check (user_id = auth.uid());
create policy "read own, admin, or driver of the bus" on public.bookings for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or exists (
    select 1 from public.profiles p join public.trips t on t.bus_id = p.bus_id
    where p.id = auth.uid() and p.role = 'driver' and t.id = bookings.trip_id));
create policy "admin update" on public.bookings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "delete own unpaid or admin" on public.bookings for delete to authenticated
  using ((user_id = auth.uid() and pay_status = 'unpaid') or public.is_admin());
