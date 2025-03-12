-- Enable the pg_trgm extension for fuzzy text matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add a tsvector column to products for full-text search
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_search tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(sku, '')), 'C')
  ) STORED;

-- Create GIN index for full-text search
CREATE INDEX IF NOT EXISTS idx_products_search ON products USING GIN (product_search);

-- Create indexes for filtering and sorting
CREATE INDEX IF NOT EXISTS idx_products_price ON products (price);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products (created_at);
CREATE INDEX IF NOT EXISTS idx_products_stock ON products (stock_quantity);

-- Create function to get price range facets
CREATE OR REPLACE FUNCTION get_price_range_facets(
  p_tenant_id uuid,
  p_search_query text
) RETURNS TABLE (
  min numeric,
  max numeric,
  count bigint
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH price_ranges AS (
    SELECT
      floor(price/100)*100 as min_price,
      floor(price/100)*100 + 99.99 as max_price
    FROM products
    WHERE tenant_id = p_tenant_id
      AND CASE
        WHEN p_search_query <> '' THEN
          product_search @@ websearch_to_tsquery('english', p_search_query)
        ELSE true
      END
  )
  SELECT
    min_price as min,
    max_price as max,
    count(*) as count
  FROM price_ranges
  GROUP BY min_price, max_price
  ORDER BY min_price;
END;
$$;

-- Create function to get product recommendations
CREATE OR REPLACE FUNCTION get_product_recommendations(
  p_tenant_id uuid,
  p_product_id uuid,
  p_price numeric,
  p_limit integer
) RETURNS TABLE (
  id uuid,
  name text,
  price numeric,
  score numeric
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH product_categories AS (
    SELECT category_id
    FROM product_categories
    WHERE product_id = p_product_id
  ),
  product_attributes AS (
    SELECT name, value
    FROM product_attributes
    WHERE product_id = p_product_id
  ),
  scored_products AS (
    SELECT
      p.id,
      p.name,
      p.price,
      (
        -- Category match score (40%)
        (CASE WHEN EXISTS (
          SELECT 1 FROM product_categories pc2
          WHERE pc2.product_id = p.id
          AND pc2.category_id IN (SELECT category_id FROM product_categories)
        ) THEN 0.4 ELSE 0 END) +
        
        -- Price similarity score (30%)
        (0.3 * (1 - ABS(p.price - p_price) / GREATEST(p.price, p_price))) +
        
        -- Attribute match score (30%)
        (0.3 * (
          SELECT COUNT(*)::float / NULLIF(total_attrs.cnt, 0)
          FROM product_attributes pa2
          CROSS JOIN (
            SELECT COUNT(*) as cnt FROM product_attributes
            WHERE product_id = p_product_id
          ) total_attrs
          WHERE pa2.product_id = p.id
          AND EXISTS (
            SELECT 1 FROM product_attributes
            WHERE product_id = p_product_id
            AND name = pa2.name
            AND value = pa2.value
          )
        ))
      ) as score
    FROM products p
    WHERE p.tenant_id = p_tenant_id
    AND p.id != p_product_id
    AND p.stock_quantity > 0
  )
  SELECT
    id,
    name,
    price,
    score
  FROM scored_products
  WHERE score > 0
  ORDER BY score DESC
  LIMIT p_limit;
END;
$$;

-- Create materialized view for product popularity
CREATE MATERIALIZED VIEW IF NOT EXISTS product_popularity AS
SELECT
  p.id,
  p.tenant_id,
  COUNT(DISTINCT oi.order_id) as order_count,
  COUNT(DISTINCT oi.order_id)::float / 
    GREATEST(
      EXTRACT(EPOCH FROM (now() - p.created_at)) / 86400, 
      1
    ) as popularity_score
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
GROUP BY p.id, p.tenant_id;

-- Create index on product popularity
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_popularity_id ON product_popularity (id);
CREATE INDEX IF NOT EXISTS idx_product_popularity_score ON product_popularity (popularity_score);

-- Create function to refresh product popularity
CREATE OR REPLACE FUNCTION refresh_product_popularity()
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY product_popularity;
END;
$$;