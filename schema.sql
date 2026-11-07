-- BusLine: schema cho Supabase (Postgres). Chạy toàn bộ trong SQL Editor.

create table public.buses (
  id bigint generated always as identity primary key,
  plate text not null unique,
  capacity int not null default 40 check (capacity > 0),
  status text not null default 'active' check (status in ('active','maintenance','retired'))
);

create table public.routes (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  start_point text not null,
  end_point text not null,
  first_trip time not null,
  last_trip time not null,
  interval_min int not null check (interval_min > 0),
  active boolean not null default true,
  check (last_trip > first_trip)
);

create table public.stops (
  id bigint generated always as identity primary key,
  route_id bigint not null references public.routes(id) on delete cascade,
  seq int not null check (seq > 0),
  name text not null,
  lat double precision,
  lng double precision
);

create table public.trips (
  id bigint generated always as identity primary key,
  route_id bigint not null references public.routes(id) on delete cascade,
  bus_id bigint references public.buses(id) on delete set null,
  departure time not null,
  direction text not null check (direction in ('di','ve')),
  status text not null default 'scheduled' check (status in ('scheduled','delayed','cancelled','done')),
  unique (bus_id, departure)  -- một xe không xuất bến 2 lần cùng giờ
);

create index on public.stops (route_id, seq);
create index on public.trips (route_id, departure);

-- Quyền admin lấy từ app_metadata của JWT (người dùng không tự sửa được)
create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
$$;

-- RLS: ai cũng đọc được, chỉ admin được ghi
do $$
declare t text;
begin
  foreach t in array array['buses','routes','stops','trips'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "public read" on public.%I for select to anon, authenticated using (true)', t);
    execute format('create policy "admin insert" on public.%I for insert to authenticated with check (public.is_admin())', t);
    execute format('create policy "admin update" on public.%I for update to authenticated using (public.is_admin()) with check (public.is_admin())', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using (public.is_admin())', t);
  end loop;
end $$;

-- Realtime cho bảng chuyến
alter publication supabase_realtime add table public.trips;

-- Cấp admin cho một tài khoản (tạo user ở Authentication > Users trước, rồi sửa email):
-- update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) || '{"role":"admin"}'::jsonb
-- where email = 'ban@example.com';

-- Dữ liệu mẫu (xoá nếu không cần)
insert into public.buses (plate, capacity) values ('51B-123.45', 60), ('51B-678.90', 60);

insert into public.routes (code, name, start_point, end_point, first_trip, last_trip, interval_min)
values ('01', 'Bến Thành – Bến xe Chợ Lớn', 'Bến Thành', 'Bến xe Chợ Lớn', '05:00', '20:00', 20);

insert into public.stops (route_id, seq, name, lat, lng)
select r.id, s.seq, s.name, s.lat, s.lng from public.routes r,
(values (1,'Bến xe buýt Bến Thành',10.7725,106.6980),
        (2,'Nhà hát Thành phố',10.7769,106.7030),
        (3,'Chợ Thái Bình',10.7690,106.6930),
        (4,'Công viên 23/9',10.7700,106.6930),
        (5,'Bến xe Chợ Lớn',10.7510,106.6520)) as s(seq,name,lat,lng)
where r.code = '01';

insert into public.trips (route_id, bus_id, departure, direction)
select r.id, (select id from public.buses order by id offset (n % 2) limit 1),
       time '05:00' + (n * 20 + d.off) * interval '1 minute', d.dir
from public.routes r, generate_series(0, 45) n,
     (values ('di', 0), ('ve', 10)) as d(dir, off)
where r.code = '01' and n * 20 + d.off <= 900;
