-- ══════════════════════════════════════════════════════
-- FTESA PRO — Supabase Database Setup
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════

-- 1. PROFILES TABLE
create table if not exists public.profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  full_name   text,
  email       text,
  plan        text default 'free' check (plan in ('free','starter','premium','luxury')),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- 2. ORDERS TABLE
create table if not exists public.orders (
  id              bigserial primary key,
  user_id         uuid references public.profiles(id) on delete cascade not null,
  template_id     int not null,
  template_name   text,
  plan            text check (plan in ('starter','premium','luxury')),
  amount          numeric(10,2),
  status          text default 'pending' check (status in ('pending','paid','delivered','cancelled')),
  guests_count    int default 0,
  wedding_data    jsonb,  -- stores bride/groom names, date, venue etc
  stripe_session  text,   -- Stripe session ID for verification
  links_generated boolean default false,
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- 3. AUTO-CREATE PROFILE ON SIGNUP
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. AUTO-UPDATE updated_at
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger orders_updated_at before update on public.orders
  for each row execute function public.update_updated_at();

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.update_updated_at();

-- 5. ROW LEVEL SECURITY (RLS)
alter table public.profiles enable row level security;
alter table public.orders   enable row level security;

-- Users can read/update their own profile
create policy "Users: own profile read"
  on public.profiles for select using (auth.uid() = id);
create policy "Users: own profile update"
  on public.profiles for update using (auth.uid() = id);

-- Users can read/insert their own orders
create policy "Users: own orders read"
  on public.orders for select using (auth.uid() = user_id);
create policy "Users: own orders insert"
  on public.orders for insert with check (auth.uid() = user_id);

-- Admin: full access (set your admin user ID here)
-- create policy "Admin: full access profiles" on public.profiles for all using (auth.uid() = 'YOUR_ADMIN_USER_ID'::uuid);
-- create policy "Admin: full access orders"   on public.orders   for all using (auth.uid() = 'YOUR_ADMIN_USER_ID'::uuid);

-- 6. INDEXES for performance
create index if not exists idx_orders_user_id   on public.orders(user_id);
create index if not exists idx_orders_status    on public.orders(status);
create index if not exists idx_orders_created   on public.orders(created_at desc);
create index if not exists idx_profiles_email   on public.profiles(email);

-- 7. SAMPLE DATA (optional - delete before production)
-- insert into public.profiles (id, full_name, email, plan) values
--   ('00000000-0000-0000-0000-000000000001', 'Artan Krasniqi', 'artan@test.com', 'premium');

-- ══════════════════════════════════════════════════════
-- DONE! Your database is ready.
-- Next steps:
-- 1. Copy your Project URL and anon key from Supabase Settings
-- 2. Replace 'YOUR_PROJECT.supabase.co' in all HTML files
-- 3. Replace 'YOUR_ANON_KEY' in all HTML files
-- 4. Configure Stripe payment links
-- 5. Deploy to Netlify or GitHub Pages
-- ══════════════════════════════════════════════════════
