-- BusLine v4: khách KHÔNG cần tài khoản/email vẫn đặt chỗ được (nhập họ tên + số điện thoại).
-- Chạy SAU schema_v3.sql.

alter table public.bookings alter column user_id drop not null;
alter table public.bookings
  add column guest_name text check (guest_name is null or length(guest_name) between 2 and 80),
  add column guest_phone text check (guest_phone is null or guest_phone ~ '^\+?[0-9 ]{8,15}$'),
  add column code text;
update public.bookings set code = upper(substr(md5(id::text || random()::text), 1, 8)) where code is null;
alter table public.bookings
  alter column code set not null,
  alter column code set default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
  add check (code ~ '^[A-Z0-9]{8}$'),
  add check (user_id is not null or (guest_name is not null and guest_phone is not null));
create unique index bookings_code_key on public.bookings (code);

-- Cập nhật trigger: khách vãng lai (không đăng nhập) phải có họ tên + SĐT; có giới hạn chống spam
create or replace function public.bookings_before() returns trigger
language plpgsql security definer set search_path = public as $$
declare t public.trips; r public.routes; bo public.stops; al public.stops;
        cap int; used int; km double precision; gn text; gp text; recent int;
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
    km := public.hav_km(new.pickup_lat, new.pickup_lng, al.lat, al.lng) * 1.3;
    new.fare := round(((r.base_fare + r.per_km * km) / 500)::numeric) * 500 * new.seats;
  end if;
  if t.bus_id is not null then
    select capacity into cap from buses where id = t.bus_id;
    select coalesce(sum(seats), 0) into used from bookings where trip_id = t.id;
    if used + new.seats > cap then raise exception 'Chuyến này đã hết chỗ.'; end if;
  end if;

  if auth.uid() is null then
    if new.guest_name is null or new.guest_phone is null then
      raise exception 'Vui lòng nhập họ tên và số điện thoại.';
    end if;
    new.user_id := null;
  else
    new.user_id := auth.uid();
    select p.full_name, p.phone into gn, gp from profiles p where p.id = auth.uid();
    new.guest_name := coalesce(new.guest_name, case when length(gn) >= 2 then gn end);
    new.guest_phone := coalesce(new.guest_phone, gp);
  end if;

  select count(*) into recent from bookings
  where pay_status = 'unpaid' and created_at > now() - interval '1 day'
    and ((new.user_id is not null and user_id = new.user_id)
      or (new.user_id is null and guest_phone = new.guest_phone));
  if recent >= 5 then
    raise exception 'Bạn đã đặt quá nhiều chỗ chưa thanh toán trong 24 giờ. Vui lòng thử lại sau.';
  end if;
  new.pay_status := 'unpaid';
  return new;
end $$;

-- Khách vãng lai được thêm đặt chỗ nhưng KHÔNG đọc được bảng (bảo vệ thông tin cá nhân)
grant insert on public.bookings to anon;
create policy "guest insert" on public.bookings for insert to anon
  with check (user_id is null and guest_name is not null);

-- Tra cứu / huỷ vé bằng mã + số điện thoại (không cần đăng nhập)
create or replace function public.lookup_booking(p_code text, p_phone text)
returns table (code text, guest_name text, route_code text, route_name text, departure time, direction text,
               delay_min int, plate text, alight_name text, seats int, fare int, pay_method text, pay_status text)
language sql stable security definer set search_path = public as $$
  select b.code, b.guest_name, r.code, r.name, t.departure, t.direction, t.delay_min, bs.plate, al.name,
         b.seats, b.fare, b.pay_method, b.pay_status
  from bookings b
  join trips t on t.id = b.trip_id join routes r on r.id = t.route_id
  left join buses bs on bs.id = t.bus_id left join stops al on al.id = b.alight_stop_id
  where b.code = upper(trim(p_code))
    and regexp_replace(coalesce(b.guest_phone, ''), '[^0-9+]', '', 'g') = regexp_replace(p_phone, '[^0-9+]', '', 'g')
$$;

create or replace function public.cancel_booking(p_code text, p_phone text) returns boolean
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  delete from bookings where code = upper(trim(p_code)) and pay_status = 'unpaid'
    and regexp_replace(coalesce(guest_phone, ''), '[^0-9+]', '', 'g') = regexp_replace(p_phone, '[^0-9+]', '', 'g');
  get diagnostics n = row_count;
  return n > 0;
end $$;

grant execute on function public.lookup_booking(text, text), public.cancel_booking(text, text) to anon, authenticated;
