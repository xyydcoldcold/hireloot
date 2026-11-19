-- Hireloot 云存档：每个用户一行 JSON 存档
-- 在 Supabase 后台 SQL Editor 里整段运行一次即可（可重复运行）

create table if not exists public.saves (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb       not null,
  rev        bigint      not null default 1,   -- 每次保存 +1，用来发现多设备冲突
  updated_at timestamptz not null default now()
);

-- 行级安全：每个人只能读写自己的那一行
alter table public.saves enable row level security;

drop policy if exists "read own save"   on public.saves;
drop policy if exists "insert own save" on public.saves;
drop policy if exists "update own save" on public.saves;
drop policy if exists "delete own save" on public.saves;

create policy "read own save"   on public.saves for select using (auth.uid() = user_id);
create policy "insert own save" on public.saves for insert with check (auth.uid() = user_id);
create policy "update own save" on public.saves for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "delete own save" on public.saves for delete using (auth.uid() = user_id);

-- updated_at 由服务器自动填，不信任客户端时间
create or replace function public.saves_touch() returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists saves_touch on public.saves;
create trigger saves_touch before insert or update on public.saves
  for each row execute function public.saves_touch();

-- 防止单个存档无限变大（约 1 MB）
alter table public.saves drop constraint if exists saves_size;
alter table public.saves add constraint saves_size check (pg_column_size(data) < 1000000);

-- 删除账号（App Store 要求 App 内能删号）：登录的人只能删自己；saves 行会跟着 on delete cascade 一起删掉
create or replace function public.delete_account() returns void
language sql security definer set search_path = '' as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
