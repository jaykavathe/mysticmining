-- Create store_settings table
create table public.store_settings (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade unique,
    store_name text not null,
    store_email text not null,
    store_phone text,
    store_address jsonb,
    currency text not null default 'USD',
    timezone text not null default 'UTC',
    tax_settings jsonb default '{}'::jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create shipping_options table
create table public.shipping_options (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    name text not null,
    description text,
    price numeric(10,2) not null,
    free_threshold numeric(10,2),
    is_active boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create tax_rules table
create table public.tax_rules (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    name text not null,
    rate numeric(5,2) not null,
    country text not null,
    state text,
    is_active boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(tenant_id, country, state)
);

-- Enable Row Level Security
alter table public.store_settings enable row level security;
alter table public.shipping_options enable row level security;
alter table public.tax_rules enable row level security;

-- Create RLS policies for store_settings
create policy "Store settings are viewable by tenant members" on public.store_settings
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = store_settings.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Store settings are insertable by tenant admins" on public.store_settings
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = store_settings.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role = 'admin'
        )
    );

create policy "Store settings are updatable by tenant admins" on public.store_settings
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = store_settings.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role = 'admin'
        )
    );

-- Create RLS policies for shipping_options
create policy "Shipping options are viewable by tenant members" on public.shipping_options
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = shipping_options.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Shipping options are insertable by tenant admins" on public.shipping_options
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = shipping_options.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager')
        )
    );

create policy "Shipping options are updatable by tenant admins" on public.shipping_options
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = shipping_options.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager')
        )
    );

create policy "Shipping options are deletable by tenant admins" on public.shipping_options
    for delete using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = shipping_options.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager')
        )
    );

-- Create RLS policies for tax_rules
create policy "Tax rules are viewable by tenant members" on public.tax_rules
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tax_rules.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Tax rules are insertable by tenant admins" on public.tax_rules
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tax_rules.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager')
        )
    );

create policy "Tax rules are updatable by tenant admins" on public.tax_rules
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tax_rules.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager')
        )
    );

create policy "Tax rules are deletable by tenant admins" on public.tax_rules
    for delete using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tax_rules.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager')
        )
    );

-- Add updated_at triggers
create trigger handle_updated_at
    before update on public.store_settings
    for each row
    execute function public.handle_updated_at();

create trigger handle_updated_at
    before update on public.shipping_options
    for each row
    execute function public.handle_updated_at();

create trigger handle_updated_at
    before update on public.tax_rules
    for each row
    execute function public.handle_updated_at();