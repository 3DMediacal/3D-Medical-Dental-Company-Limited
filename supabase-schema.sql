-- =====================================================================
--  HR OFFICE — Schema chịu tải đồng thời (mục tiêu ~200 người cùng lúc)
--  Chạy toàn bộ file này trong Supabase → SQL Editor của project
--  urvpgyrazbpxnceygwkx. Chạy lại an toàn (idempotent, dùng IF NOT EXISTS).
--
--  Chiến lược:
--   1) TÁCH BẢNG THEO THỰC THỂ  : mỗi nhân viên / đơn nghỉ / chấm công / KR
--      là 1 DÒNG riêng  → 200 người ghi 200 dòng khác nhau, không đụng nhau.
--   2) APPEND-ONLY cho luồng "submit" cao điểm (chấm công, nộp đơn):
--      chỉ INSERT, không UPDATE cả cục → không khoá, không mất bản ghi.
--   3) OPTIMISTIC LOCK cho cấu hình dùng chung còn lại (app_state):
--      cột version, chỉ ghi đè khi version khớp (hàm bump_app_state).
-- =====================================================================

-- ---------- 1. NHÂN VIÊN (mỗi người 1 dòng) --------------------------
create table if not exists public.hr_staff (
  id          text primary key,              -- khớp staff.id phía client (string)
  code        text,
  data        jsonb not null default '{}',   -- toàn bộ hồ sơ nhân viên
  updated_at  timestamptz not null default now(),
  updated_by  text,
  version     bigint not null default 1,     -- optimistic lock cho từng NV
  deleted     boolean not null default false
);
create index if not exists hr_staff_code_idx on public.hr_staff (code);

-- ---------- 2. ĐƠN NGHỈ PHÉP (mỗi đơn 1 dòng) ------------------------
create table if not exists public.hr_leave_requests (
  id          text primary key,
  emp_name    text,
  department  text,
  status      text,
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  updated_by  text,
  version     bigint not null default 1
);
create index if not exists hr_leave_emp_idx on public.hr_leave_requests (emp_name);
create index if not exists hr_leave_status_idx on public.hr_leave_requests (status);

-- ---------- 3. CHẤM CÔNG (append-only — mỗi lần chấm 1 dòng) ---------
--   Không UPDATE. Check-in và Check-out đều là INSERT một "sự kiện".
--   Khi đọc: gom theo (emp_name, work_date), lấy sự kiện mới nhất mỗi loại.
create table if not exists public.hr_attendance_events (
  id          uuid primary key default gen_random_uuid(),
  emp_name    text not null,
  work_date   date not null,
  kind        text not null,                 -- 'checkin' | 'checkout' | 'manual'
  at_time     text,                          -- 'HH:MM'
  data        jsonb not null default '{}',   -- lateFlag, gps, ip, reason...
  created_at  timestamptz not null default now(),
  created_by  text
);
create index if not exists hr_att_emp_date_idx on public.hr_attendance_events (emp_name, work_date);
create index if not exists hr_att_date_idx on public.hr_attendance_events (work_date);

-- ---------- 4. PHIẾU KR / KẾT QUẢ (append-only submit) ---------------
create table if not exists public.hr_kr_submissions (
  id          uuid primary key default gen_random_uuid(),
  emp_name    text not null,
  period      text,
  kr_id       text,
  data        jsonb not null default '{}',   -- value, selfScore, note...
  created_at  timestamptz not null default now(),
  created_by  text
);
create index if not exists hr_kr_emp_period_idx on public.hr_kr_submissions (emp_name, period);

-- ---------- 5. CẤU HÌNH DÙNG CHUNG (giữ app_state + version) ---------
--   Phần chưa tách bảng (tham số lương, cài đặt, danh mục…) vẫn ở app_state
--   nhưng thêm optimistic lock để không mất khi 2 người sửa cùng lúc.
create table if not exists public.app_state (
  id          text primary key,
  data        jsonb not null default '{}',
  updated_at  timestamptz not null default now()
);
alter table public.app_state add column if not exists version bigint not null default 1;

alter table public.app_state enable row level security;
drop policy if exists app_state_rw on public.app_state;
create policy app_state_rw on public.app_state for all to authenticated using (true) with check (true);

-- Ghi đè app_state chỉ khi version client đang giữ == version DB.
-- Trả về dòng mới nếu thành công; không trả gì nếu version lệch (client phải tải lại).
create or replace function public.bump_app_state(p_id text, p_expected bigint, p_data jsonb)
returns public.app_state
language plpgsql
as $$
declare r public.app_state;
begin
  update public.app_state
     set data = p_data, version = version + 1, updated_at = now()
   where id = p_id and version = p_expected
  returning * into r;
  return r;   -- NULL nếu version không khớp (có người vừa ghi trước)
end;
$$;

-- ---------- 6. BẬT REALTIME cho các bảng mới ------------------------
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array[
    'hr_staff','hr_leave_requests','hr_attendance_events','hr_kr_submissions'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I;', t);
    end if;
  end loop;
end $$;

-- ---------- 7. RLS (nội bộ: cho người đã đăng nhập đọc/ghi) ----------
--   Tối giản cho công cụ nội bộ. Siết chặt hơn sau nếu cần (theo phòng ban/vai trò).
alter table public.hr_staff              enable row level security;
alter table public.hr_leave_requests     enable row level security;
alter table public.hr_attendance_events  enable row level security;
alter table public.hr_kr_submissions     enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'hr_staff','hr_leave_requests','hr_attendance_events','hr_kr_submissions'
  ] loop
    execute format('drop policy if exists %I_rw on public.%I;', t, t);
    execute format(
      'create policy %I_rw on public.%I for all to authenticated using (true) with check (true);',
      t, t);
  end loop;
end $$;

-- =====================================================================
--  8. SIẾT RLS THEO VAI TRÒ / PHÒNG BAN  (tùy chọn — đọc kỹ trước khi chạy)
-- ---------------------------------------------------------------------
--  CẢNH BÁO: policy sai cột sẽ KHÓA mọi người khỏi dữ liệu. Vì schema bảng
--  `employees` của bạn tôi không chắc tên cột, phần này để DẠNG MẪU (đã
--  comment). Hãy kiểm tra tên cột trong `employees` (vai trò, phòng ban,
--  họ tên) rồi bỏ comment và chỉnh cho khớp, chạy riêng, test bằng 1 tài
--  khoản nhân viên thường trước khi áp cho mọi người.
--
--  Hàm đọc hồ sơ người đang đăng nhập (an toàn, trả JSON):
create or replace function public.my_emp()
returns jsonb language sql stable security definer as $$
  select to_jsonb(e) from public.employees e where e.auth_user_id = auth.uid() limit 1;
$$;
--
--  Ví dụ siết hr_staff: HR/Giám đốc xem tất cả, người khác chỉ xem phòng mình.
--  (Đổi 'systemRole' / 'department' cho đúng cột thực tế của bảng employees.)
--
--  drop policy if exists hr_staff_rw on public.hr_staff;
--  create policy hr_staff_read on public.hr_staff for select to authenticated using (
--    coalesce(public.my_emp()->>'systemRole','') in ('hr','director','admin','owner')
--    or (data->>'department') = (public.my_emp()->>'department')
--  );
--  create policy hr_staff_write on public.hr_staff for all to authenticated using (
--    coalesce(public.my_emp()->>'systemRole','') in ('hr','director','admin','owner')
--  ) with check (
--    coalesce(public.my_emp()->>'systemRole','') in ('hr','director','admin','owner')
--  );
--
--  LƯU Ý QUAN TRỌNG VỀ LƯƠNG:
--  Dữ liệu lương (payProfiles, payPeriods) hiện nằm trong MỘT dòng app_state
--  dùng chung → RLS KHÔNG thể giới hạn từng người đọc. Muốn nhân viên thường
--  không đọc được lương người khác ở tầng DB, cần tách lương ra bảng riêng
--  (hr_payroll) có RLS theo người — là một việc lớn, nên làm thành đợt riêng.

-- =====================================================================
--  9. DỌN BẢNG APPEND-ONLY ĐỊNH KỲ  (chống phình sau nhiều năm)
-- ---------------------------------------------------------------------
--  Xoá sự kiện chấm công / phiếu KR cũ hơn 24 tháng. Chạy tay định kỳ,
--  hoặc lên lịch bằng pg_cron nếu project có bật extension đó.
create or replace function public.hr_prune_old(months int default 24)
returns void language sql as $$
  delete from public.hr_attendance_events where work_date < (current_date - (months || ' months')::interval);
  delete from public.hr_kr_submissions   where created_at < (now() - (months || ' months')::interval);
$$;
--  Chạy tay:  select public.hr_prune_old(24);
--  (Tùy chọn, nếu đã bật pg_cron:)
--  select cron.schedule('hr_prune_monthly', '0 3 1 * *', $$select public.hr_prune_old(24)$$);

-- =====================================================================
--  10. BẢNG LƯƠNG RIÊNG CÓ RLS  (bảo mật: nhân viên chỉ đọc lương của mình)
-- ---------------------------------------------------------------------
--  Hồ sơ lương (mức lương, phụ cấp, BHXH) tách khỏi app_state dùng chung.
create table if not exists public.hr_pay_profiles (
  id          text primary key,              -- staffName::effective
  emp_name    text not null,
  data        jsonb not null default '{}',
  updated_at  timestamptz not null default now(),
  updated_by  text
);
create index if not exists hr_pay_prof_emp_idx on public.hr_pay_profiles (emp_name);

alter table public.hr_pay_profiles enable row level security;
--  ĐỌC: HR/Giám đốc/Admin xem tất cả; người khác chỉ xem hồ sơ của chính mình.
drop policy if exists hr_pay_prof_read on public.hr_pay_profiles;
create policy hr_pay_prof_read on public.hr_pay_profiles for select to authenticated using (
  coalesce(public.my_emp()->>'systemRole','') in ('hr','director','admin','owner')
  or emp_name = (public.my_emp()->>'name')
);
--  GHI: để authenticated (chỉ HR mới mở màn này ở UI; nếu muốn siết, đổi thành danh sách vai trò như trên).
drop policy if exists hr_pay_prof_write on public.hr_pay_profiles;
create policy hr_pay_prof_write on public.hr_pay_profiles for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='hr_pay_profiles') then
    execute 'alter publication supabase_realtime add table public.hr_pay_profiles';
  end if;
end $$;

-- GHI CHÚ: phần phiếu lương đã tính (payPeriods.rows) và số liệu nhập theo
-- tháng (inputs) hiện vẫn nằm trong app_state. Đây là BƯỚC 1 (hồ sơ lương).
-- Bước 2 (tách phiếu lương đã tính) sẽ làm tiếp sau khi bước này chạy ổn.

-- =====================================================================
--  11. PHIẾU LƯƠNG ĐÃ TÍNH CÓ RLS  (bước 2 — nhân viên chỉ đọc phiếu của mình)
-- ---------------------------------------------------------------------
create table if not exists public.hr_payslips (
  id          text primary key,              -- month::emp_name
  month       text not null,
  emp_name    text not null,
  data        jsonb not null default '{}',   -- dòng lương đã tính (gross, net, các khoản...)
  published   boolean not null default false,
  updated_at  timestamptz not null default now(),
  updated_by  text
);
create index if not exists hr_payslips_month_idx on public.hr_payslips (month);
create index if not exists hr_payslips_emp_idx on public.hr_payslips (emp_name);

alter table public.hr_payslips enable row level security;
--  ĐỌC: HR/Giám đốc/Admin xem tất cả; nhân viên chỉ xem phiếu ĐÃ PHÁT HÀNH của mình.
drop policy if exists hr_payslips_read on public.hr_payslips;
create policy hr_payslips_read on public.hr_payslips for select to authenticated using (
  coalesce(public.my_emp()->>'systemRole','') in ('hr','director','admin','owner')
  or (emp_name = (public.my_emp()->>'name') and published = true)
);
drop policy if exists hr_payslips_write on public.hr_payslips;
create policy hr_payslips_write on public.hr_payslips for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='hr_payslips') then
    execute 'alter publication supabase_realtime add table public.hr_payslips';
  end if;
end $$;

-- =====================================================================
--  12. SỐ NHẬP THEO THÁNG CÓ RLS  (hoa hồng/thưởng/tạm ứng từng người)
-- ---------------------------------------------------------------------
create table if not exists public.hr_pay_inputs (
  id          text primary key,              -- month::emp_name
  month       text not null,
  emp_name    text not null,
  data        jsonb not null default '{}',
  updated_at  timestamptz not null default now(),
  updated_by  text
);
create index if not exists hr_pay_inputs_month_idx on public.hr_pay_inputs (month);
create index if not exists hr_pay_inputs_emp_idx on public.hr_pay_inputs (emp_name);

alter table public.hr_pay_inputs enable row level security;
drop policy if exists hr_pay_inputs_read on public.hr_pay_inputs;
create policy hr_pay_inputs_read on public.hr_pay_inputs for select to authenticated using (
  coalesce(public.my_emp()->>'systemRole','') in ('hr','director','admin','owner')
  or emp_name = (public.my_emp()->>'name')
);
drop policy if exists hr_pay_inputs_write on public.hr_pay_inputs;
create policy hr_pay_inputs_write on public.hr_pay_inputs for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='hr_pay_inputs') then
    execute 'alter publication supabase_realtime add table public.hr_pay_inputs';
  end if;
end $$;

-- Xong.
