-- Create products table (referenced by inventory)
create table public.products (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    name text not null,
    sku text not null,
    description text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(tenant_id, sku)
);

-- Create inventory table
create table public.inventory (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    product_id uuid references public.products(id) on delete cascade,
    warehouse_code text not null,
    quantity integer not null default 0,
    reorder_point integer,
    reorder_quantity integer,
    last_counted_at timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(tenant_id, product_id, warehouse_code)
);

-- Create inventory_adjustments table
create table public.inventory_adjustments (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    product_id uuid references public.products(id) on delete cascade,
    warehouse_code text not null,
    adjustment_type text not null check (adjustment_type in ('add', 'subtract', 'set')),
    quantity integer not null,
    reason text not null,
    reference_number text,
    notes text,
    adjusted_by uuid references auth.users(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_adjustments enable row level security;

-- Create RLS policies for products
create policy "Products are viewable by tenant members" on public.products
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = products.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Products are insertable by tenant staff+" on public.products
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = products.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

create policy "Products are updatable by tenant staff+" on public.products
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = products.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

-- Create RLS policies for inventory
create policy "Inventory is viewable by tenant members" on public.inventory
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = inventory.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Inventory is insertable by tenant staff+" on public.inventory
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = inventory.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

create policy "Inventory is updatable by tenant staff+" on public.inventory
    for update using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = inventory.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

-- Create RLS policies for inventory_adjustments
create policy "Inventory adjustments are viewable by tenant members" on public.inventory_adjustments
    for select using (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = inventory_adjustments.tenant_id
            and tenant_members.user_id = auth.uid()
        )
    );

create policy "Inventory adjustments are insertable by tenant staff+" on public.inventory_adjustments
    for insert with check (
        exists (
            select 1 from public.tenant_members
            where tenant_members.tenant_id = inventory_adjustments.tenant_id
            and tenant_members.user_id = auth.uid()
            and tenant_members.role in ('admin', 'manager', 'staff')
        )
    );

-- Add updated_at triggers
create trigger handle_updated_at
    before update on public.products
    for each row
    execute function public.handle_updated_at();

create trigger handle_updated_at
    before update on public.inventory
    for each row
    execute function public.handle_updated_at();