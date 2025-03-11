-- Create customer_profiles table
create table public.customer_profiles (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    first_name text,
    last_name text,
    email text not null,
    phone text,
    marketing_consent boolean default false,
    notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(tenant_id, email)
);

-- Create customer_addresses table
create table public.customer_addresses (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    customer_id uuid references public.customer_profiles(id) on delete cascade,
    address_type text not null check (address_type in ('shipping', 'billing')),
    is_default boolean default false,
    first_name text,
    last_name text,
    company text,
    address_line1 text not null,
    address_line2 text,
    city text not null,
    state text,
    postal_code text not null,
    country text not null,
    phone text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security
alter table public.customer_profiles enable row level security;
alter table public.customer_addresses enable row level security;

-- Create RLS policies for customer_profiles
create policy "Customer profiles are viewable by tenant members" on public.customer_profiles
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_profiles.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Customer profiles are insertable by tenant staff+" on public.customer_profiles
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_profiles.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

create policy "Customer profiles are updatable by tenant staff+" on public.customer_profiles
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_profiles.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

-- Create RLS policies for customer_addresses
create policy "Customer addresses are viewable by tenant members" on public.customer_addresses
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_addresses.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Customer addresses are insertable by tenant staff+" on public.customer_addresses
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_addresses.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

create policy "Customer addresses are updatable by tenant staff+" on public.customer_addresses
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_addresses.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

create policy "Customer addresses are deletable by tenant staff+" on public.customer_addresses
    for delete using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = customer_addresses.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

-- Add updated_at triggers
create trigger handle_updated_at
    before update on public.customer_profiles
    for each row
    execute function public.handle_updated_at();

create trigger handle_updated_at
    before update on public.customer_addresses
    for each row
    execute function public.handle_updated_at();