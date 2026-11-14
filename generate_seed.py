#!/usr/bin/env python3
"""Sinh dữ liệu MẪU cho BusLine (25 tuyến). Chạy: python3 generate_seed.py
Tọa độ các địa danh là xấp xỉ; trạm trung gian nội suy theo đường thẳng. Không phải lịch chạy chính thức."""
import math, random
random.seed(2026)

L = {  # địa danh: (tên, vĩ độ, kinh độ)
 'BT':('Bến Thành',10.7725,106.6980),'CV23':('Công viên 23/9',10.7690,106.6935),'HCR':('Hồ Con Rùa',10.7826,106.6959),
 'CTD':('Chợ Tân Định',10.7889,106.6906),'TCV':('Thảo Cầm Viên',10.7876,106.7050),'BK':('ĐH Bách Khoa',10.7721,106.6579),
 'HV':('An Đông Plaza',10.7552,106.6720),'VL':('Công viên Văn Lang',10.7548,106.6685),'CRAY':('Bệnh viện Chợ Rẫy',10.7570,106.6590),
 'BXCL':('Bến xe Chợ Lớn',10.7497,106.6512),'BXMT':('Bến xe Miền Tây',10.7414,106.6350),'PL':('Ngã tư Phú Lâm',10.7527,106.6320),
 'BXQ8':('Bến xe Quận 8',10.7380,106.6530),'DS':('Đầm Sen',10.7625,106.6366),'LTR':('Công viên Lê Thị Riêng',10.7840,106.6670),
 'BH':('Ngã tư Bảy Hiền',10.7930,106.6530),'TSN':('Sân bay Tân Sơn Nhất',10.8188,106.6520),'PN':('Ngã tư Phú Nhuận',10.7950,106.6800),
 'BC':('Chợ Bà Chiểu',10.8020,106.6970),'HX':('Ngã tư Hàng Xanh',10.8010,106.7110),'L81':('Landmark 81',10.7950,106.7218),
 'TD':('Thảo Điền',10.8040,106.7400),'GD':('Công viên Gia Định',10.8120,106.6790),'NSGV':('Ngã sáu Gò Vấp',10.8380,106.6740),
 'BXMD':('Bến xe Miền Đông (cũ)',10.8147,106.7102),'BTR':('Ngã tư Bình Triệu',10.8310,106.7220),'CTDc':('Chợ Thủ Đức',10.8500,106.7550),
 'ST':('Khu du lịch Suối Tiên',10.8661,106.8030),'DHQG':('ĐH Quốc gia TP.HCM',10.8750,106.8010),'BXMDm':('Bến xe Miền Đông mới',10.8781,106.8134),
 'SHTP':('Khu Công nghệ cao',10.8520,106.8090),'BXAS':('Bến xe An Sương',10.8416,106.6139),'QTSC':('Công viên phần mềm Quang Trung',10.8540,106.6270),
 'HM':('Chợ Hóc Môn',10.8860,106.5920),'CC':('Bến xe Củ Chi',10.9730,106.4930),'AEON':('AEON Tân Phú',10.8026,106.6176),
 'BCH':('Chợ Bình Chánh',10.6676,106.5736),'NB':('Chợ Nhà Bè',10.6950,106.7370),'PMH':('Phú Mỹ Hưng',10.7290,106.7220),'KT':('Cầu Kênh Tẻ',10.7580,106.7070)}

R = [('01','BT,HV,VL,CRAY,BXCL',12),('02','BT,HV,VL,BXCL,PL,BXMT',12),('03','BT,CV23,BK,LTR,DS',15),
 ('04','BT,HCR,LTR,BH,TSN',15),('05','BXCL,PL,BXMT,BCH',20),('06','BXQ8,HV,BT',15),('07','BT,CV23,TCV,L81,TD',15),
 ('08','BT,HCR,CTD,BC,HX,L81',12),('09','BT,KT,PMH',15),('10','BT,KT,PMH,NB',20),('11','BT,HCR,CTD,BC,BXMD',15),
 ('12','BT,HCR,HX,BTR,CTDc,ST',10),('13','BXMD,BTR,CTDc,ST,DHQG',12),('14','BXMD,BC,PN,LTR,BXCL,BXMT',15),
 ('15','BXAS,AEON,BH,LTR,BT',15),('16','BXAS,QTSC,HM',20),('17','NSGV,GD,PN,HCR,BT',12),
 ('18','BXCL,CRAY,LTR,PN,BC,BXMD,BTR,CTDc,ST,DHQG',20),('19','BT,HCR,HX,BTR,CTDc,ST,DHQG',15),('20','BXMDm,SHTP,ST,DHQG',25),
 ('DD1','BT,LTR,BXAS,QTSC,HM,CC',30),('DD2','BXMT,BCH',30),('DD3','HM,CC',30),('DD4','BT,KT,PMH,NB',25),('DD5','CTDc,ST,DHQG',25)]

def hav(a, b):
    p = math.pi / 180; dl = (b[0]-a[0])*p; dn = (b[1]-a[1])*p
    u = math.sin(dl/2)**2 + math.cos(a[0]*p)*math.cos(b[0]*p)*math.sin(dn/2)**2
    return 12742 * math.asin(math.sqrt(u))
q = lambda s: "'" + s.replace("'", "''") + "'"
hhmm = lambda m: f'{m//60:02d}:{m%60:02d}'
peak = lambda m: 390 <= m <= 510 or 990 <= m <= 1110

routes, stops, buses, trips = [], [], [], {}
bus_n = 0
for ri, (code, ids, base) in enumerate(R):
    flag = code.startswith('DD'); pts = [L[i] for i in ids.split(',')]
    raw = [(pts[0][0], pts[0][1], pts[0][2])]; step = 3.0 if flag else 2.2
    for a, b in zip(pts, pts[1:]):
        n = int(hav(a[1:], b[1:]) // step)
        for k in range(1, n+1):
            f = k/(n+1); raw.append((None, a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f))
        raw.append(b)
    cum, rows, speed = 0.0, [], (24 if flag else 17)
    for i, (nm, la, ln) in enumerate(raw):
        if i: cum += hav(raw[i-1][1:], (la, ln)) * 1.3
        rows.append((nm or f'Trạm {code}-{i+1:02d}', la, ln, round(cum/speed*60 + 0.6*i)))
    tot = rows[-1][3]
    first = 330 if flag else 300 + (ri % 3) * 10
    last = 1170 if flag else 1230 - (ri % 4) * 15
    fare = (8000, 1500) if flag else ((6000 if cum <= 15 else 7000), 0)
    name = f'{pts[0][0]} – {pts[-1][0]}' + (' (xe đón dọc đường)' if flag else '')
    routes.append(f"({q(code)},{q(name)},{q(pts[0][0])},{q(pts[-1][0])},'{hhmm(first)}','{hhmm(last)}',{base},{q('flag_down' if flag else 'fixed')},{fare[0]},{fare[1]})")
    for i, (nm, la, ln, off) in enumerate(rows):
        stops.append(f"({q(code)},{i+1},{q(nm)},{la:.6f},{ln:.6f},{off})")
    # lịch xuất bến: giờ cao điểm dày hơn
    ev = []
    for d, t0 in (('di', first), ('ve', first + max(3, base//2))):
        t = t0
        while t <= last:
            ev.append((t, d)); t += max(5, round(base * (0.7 if peak(t) else 1)))
    ev.sort()
    cong = random.uniform(0.8, 1.4); cap = 29 if flag else random.choice([40, 60])
    pool, out = [], []
    for t, d in ev:
        need = 'A' if d == 'di' else 'B'
        av = [b for b in pool if b['loc'] == need and b['free'] <= t]
        if av: b = min(av, key=lambda x: x['free'])
        else:
            bus_n += 1; n = 10000 + bus_n * 13
            b = {'plate': f'51B-{n//100:03d}.{n%100:02d}', 'loc': need, 'free': 0}; pool.append(b)
            buses.append(f"({q(b['plate'])},{cap})")
        mean = (5.5 if peak(t) else 2.0 if 540 <= t <= 960 else 1.0) * cong
        dl = min(25, int(random.expovariate(1/mean)))
        b['free'] = t + dl + round(tot * (1.25 if peak(t) else 1.0)) + 6
        b['loc'] = 'B' if d == 'di' else 'A'
        out.append(f"({q(code)},{q(b['plate'])},'{hhmm(t)}','{d}',{dl})")
    trips[code] = out

with open('seed_1_routes_stops_buses.sql', 'w', encoding='utf-8') as f:
    f.write("-- DỮ LIỆU MẪU. Cảnh báo: xoá toàn bộ tuyến, điểm dừng, xe, chuyến, đặt chỗ hiện có.\n")
    f.write("delete from public.bookings; delete from public.trips; delete from public.stops; delete from public.routes; delete from public.buses;\n")
    f.write("insert into public.routes (code,name,start_point,end_point,first_trip,last_trip,interval_min,service_type,base_fare,per_km) values\n" + ",\n".join(routes) + ";\n")
    f.write("insert into public.stops (route_id,seq,name,lat,lng,offset_min)\nselect r.id,v.seq,v.name,v.lat,v.lng,v.off from (values\n" + ",\n".join(stops) + "\n) v(code,seq,name,lat,lng,off) join public.routes r on r.code=v.code;\n")
    f.write("insert into public.buses (plate,capacity) values\n" + ",\n".join(buses) + ";\n")

total = sum(len(v) for v in trips.values()); half = 0; parts = ([], [])
for code, rows in trips.items():
    (parts[0] if half < total/2 else parts[1]).extend(rows); half += len(rows)
for i, rows in enumerate(parts):
    with open(f'seed_{i+2}_trips_{"ab"[i]}.sql', 'w', encoding='utf-8') as f:
        f.write("insert into public.trips (route_id,bus_id,departure,direction,delay_min,status)\n"
                "select r.id,b.id,v.dep::time,v.dir,v.dl,case when v.dl>=5 then 'delayed' else 'scheduled' end\nfrom (values\n"
                + ",\n".join(rows) + "\n) v(code,plate,dep,dir,dl) join public.routes r on r.code=v.code join public.buses b on b.plate=v.plate;\n")
print(f'{len(routes)} tuyến, {len(stops)} điểm dừng, {len(buses)} xe, {total} chuyến')
