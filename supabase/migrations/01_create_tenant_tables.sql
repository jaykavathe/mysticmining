-- Create tenants table
create table public.tenants (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    settings jsonb default '{}'::jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create tenant_members table
create table public.tenant_members (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    role text not null check (role in ('admin', 'manager', 'staff')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(tenant_id, user_id)
);

-- Enable Row Level Security
alter table public.tenants enable row level security;
alter table public.tenant_members enable row level security;

-- Create RLS policies for tenants
create policy "Tenants are viewable by members" on public.tenants
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tenants.id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Tenants are insertable by admins" on public.tenants
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tenants.id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role = 'admin'
        )
    );

create policy "Tenants are updatable by admins" on public.tenants
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tenants.id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role = 'admin'
        )
    );

-- Create RLS policies for tenant_members
create policy "Tenant members are viewable by tenant members" on public.tenant_members
    for select using (
        exists (
            select 1 from public.tenant_members as tm
            where tm.tenant_id = tenant_members.tenant_id
            and tm.user_id = auth.uid()
        )
    );

create policy "Tenant members are insertable by tenant admins" on public.tenant_members
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tenant_id
            and user_id = auth.uid()
            and role = 'admin'
        )
    );

create policy "Tenant members are updatable by tenant admins" on public.tenant_members
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = tenant_id
            and user_id = auth.uid()
            and role = 'admin'
        )
    );

-- Create updated_at trigger function
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = timezone('utc'::text, now());
    return new;
end;
$$ language plpgsql;

-- Add updated_at triggers
create trigger handle_updated_at
    before update on public.tenants
    for each row
    execute function public.handle_updated_at();

create trigger handle_updated_at
    before update on public.tenant_members
    for each row
    execute function public.handle_updated_at();