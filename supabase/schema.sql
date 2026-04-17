-- =====================================================================
-- Stoveside — Supabase schema
-- Run this in your Supabase SQL editor once the project is created.
-- =====================================================================

-- Cleanup (safe to re-run)
drop table if exists order_items cascade;
drop table if exists orders cascade;
drop table if exists availability cascade;
drop table if exists menu_items cascade;
drop table if exists kitchens cascade;
drop table if exists permit_applications cascade;
drop table if exists profiles cascade;

-- =====================================================================
-- profiles — one row per auth.users user
-- =====================================================================
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  full_name text,
  phone text,
  is_operator boolean default false,
  created_at timestamptz default now()
);

-- =====================================================================
-- permit_applications — wizard outputs
-- =====================================================================
create table permit_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  county text not null,
  kitchen_name text,
  address text,
  water_source text check (water_source in ('municipal','well')),
  household_size int,
  cuisine text,
  sample_dishes text[],
  schedule text,
  status text default 'draft' check (status in ('draft','submitted','inspection_scheduled','approved','denied')),
  permit_number text,
  approved_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =====================================================================
-- kitchens — approved MEHKO operators
-- =====================================================================
create table kitchens (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id) on delete cascade,
  name text not null,
  chef_name text,
  story text,
  photo_url text,
  cuisine text,
  neighborhood text,
  city text default 'San Diego',
  state text default 'CA',
  county text,
  permit_number text unique,
  last_inspected date,
  is_live boolean default false,
  lat double precision,
  lng double precision,
  created_at timestamptz default now()
);

-- =====================================================================
-- menu_items — per-kitchen menu
-- =====================================================================
create table menu_items (
  id uuid primary key default gen_random_uuid(),
  kitchen_id uuid references kitchens(id) on delete cascade,
  name text not null,
  description text,
  price numeric(7,2) not null check (price >= 0),
  emoji text,
  photo_url text,
  allergens text[],
  is_available boolean default true,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- =====================================================================
-- availability — pickup windows; enforces 30/day, 60/week caps
-- =====================================================================
create table availability (
  id uuid primary key default gen_random_uuid(),
  kitchen_id uuid references kitchens(id) on delete cascade,
  start_time timestamptz not null,
  end_time timestamptz not null,
  max_meals int default 30 check (max_meals <= 30),
  meals_claimed int default 0,
  created_at timestamptz default now()
);

-- =====================================================================
-- orders
-- =====================================================================
create table orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references profiles(id),
  kitchen_id uuid references kitchens(id),
  pickup_time timestamptz not null,
  total numeric(8,2) not null,
  status text default 'confirmed' check (status in ('confirmed','ready','picked_up','cancelled')),
  payment_method text default 'cash_or_venmo',
  notes text,
  created_at timestamptz default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  menu_item_id uuid references menu_items(id),
  name_snapshot text not null,      -- name at time of order
  price_snapshot numeric(7,2) not null,
  qty int not null check (qty > 0)
);

-- =====================================================================
-- Indexes
-- =====================================================================
create index idx_kitchens_city on kitchens(city) where is_live = true;
create index idx_kitchens_owner on kitchens(owner_id);
create index idx_menu_kitchen on menu_items(kitchen_id) where is_available = true;
create index idx_orders_customer on orders(customer_id, created_at desc);
create index idx_orders_kitchen on orders(kitchen_id, pickup_time);
create index idx_availability_kitchen on availability(kitchen_id, start_time);
create index idx_permit_user on permit_applications(user_id);

-- =====================================================================
-- Row Level Security
-- =====================================================================
alter table profiles enable row level security;
alter table permit_applications enable row level security;
alter table kitchens enable row level security;
alter table menu_items enable row level security;
alter table availability enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

-- Profiles: users manage their own, everyone can read basic info for kitchens they own
create policy "profiles_self_read" on profiles for select using (auth.uid() = id);
create policy "profiles_self_write" on profiles for update using (auth.uid() = id);
create policy "profiles_self_insert" on profiles for insert with check (auth.uid() = id);

-- Permits: only the applicant sees their own
create policy "permits_self_all" on permit_applications for all using (auth.uid() = user_id);

-- Kitchens: publicly readable when live; owner can manage
create policy "kitchens_public_read" on kitchens for select using (is_live = true);
create policy "kitchens_owner_all" on kitchens for all using (auth.uid() = owner_id);

-- Menu items: publicly readable when kitchen is live; owner manages
create policy "menu_public_read" on menu_items for select using (
  exists (select 1 from kitchens k where k.id = menu_items.kitchen_id and k.is_live = true)
);
create policy "menu_owner_all" on menu_items for all using (
  exists (select 1 from kitchens k where k.id = menu_items.kitchen_id and k.owner_id = auth.uid())
);

-- Availability: publicly readable when kitchen is live; owner manages
create policy "avail_public_read" on availability for select using (
  exists (select 1 from kitchens k where k.id = availability.kitchen_id and k.is_live = true)
);
create policy "avail_owner_all" on availability for all using (
  exists (select 1 from kitchens k where k.id = availability.kitchen_id and k.owner_id = auth.uid())
);

-- Orders: customers see their own; operators see orders for their kitchen
create policy "orders_customer_read" on orders for select using (auth.uid() = customer_id);
create policy "orders_operator_read" on orders for select using (
  exists (select 1 from kitchens k where k.id = orders.kitchen_id and k.owner_id = auth.uid())
);
create policy "orders_customer_insert" on orders for insert with check (auth.uid() = customer_id);
create policy "orders_operator_update" on orders for update using (
  exists (select 1 from kitchens k where k.id = orders.kitchen_id and k.owner_id = auth.uid())
);

-- Order items follow the order's visibility
create policy "order_items_visible" on order_items for select using (
  exists (
    select 1 from orders o
    where o.id = order_items.order_id
      and (o.customer_id = auth.uid()
           or exists (select 1 from kitchens k where k.id = o.kitchen_id and k.owner_id = auth.uid()))
  )
);
create policy "order_items_insert" on order_items for insert with check (
  exists (select 1 from orders o where o.id = order_items.order_id and o.customer_id = auth.uid())
);

-- =====================================================================
-- Trigger to auto-create profile row on signup
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- Seed data for San Diego launch
-- =====================================================================
-- (Insert seed kitchens only after you have a real user to own them.)
-- Example:
-- insert into kitchens (owner_id, name, chef_name, neighborhood, cuisine, permit_number, is_live)
-- values ('<your-user-uuid>', 'Grandma Rosa''s', 'Rosa Hernandez', 'North Park', 'Mexican', 'MEHKO-SD-1204', true);
