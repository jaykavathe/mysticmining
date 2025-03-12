import { z } from 'zod';

// Common validation patterns
const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const phoneRegex = /^\+?[1-9]\d{1,14}$/;
const skuRegex = /^[A-Z0-9]{4,16}$/;

// Common schemas
export const idSchema = z.string().regex(uuidRegex, 'Invalid UUID format');
export const tenantIdSchema = z.string().regex(uuidRegex, 'Invalid tenant ID format');
export const emailSchema = z.string().email('Invalid email format');
export const phoneSchema = z.string().regex(phoneRegex, 'Invalid phone number format');
export const priceSchema = z.number().min(0, 'Price must be non-negative');
export const quantitySchema = z.number().int().min(0, 'Quantity must be non-negative');

// Product schemas
export const productSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200, 'Name is too long'),
  description: z.string().max(2000, 'Description is too long').optional(),
  sku: z.string().regex(skuRegex, 'Invalid SKU format'),
  price: priceSchema,
  stock_quantity: quantitySchema,
  categories: z.array(idSchema).min(1, 'At least one category is required'),
  attributes: z.record(
    z.string().min(1, 'Attribute name is required'),
    z.array(z.string().min(1, 'Attribute value is required'))
  ).optional(),
  images: z.array(z.string().url('Invalid image URL')).optional(),
  is_active: z.boolean().default(true),
  metadata: z.record(z.string(), z.any()).optional()
});

// Order schemas
export const addressSchema = z.object({
  street: z.string().min(1, 'Street is required'),
  city: z.string().min(1, 'City is required'),
  state: z.string().min(1, 'State is required'),
  postal_code: z.string().min(1, 'Postal code is required'),
  country: z.string().min(2, 'Country is required').max(2, 'Use ISO country code'),
  phone: phoneSchema
});

export const orderItemSchema = z.object({
  product_id: idSchema,
  quantity: z.number().int().positive('Quantity must be positive'),
  unit_price: priceSchema,
  metadata: z.record(z.string(), z.any()).optional()
});

export const orderSchema = z.object({
  customer_id: idSchema,
  billing_address: addressSchema,
  shipping_address: addressSchema,
  items: z.array(orderItemSchema).min(1, 'Order must contain at least one item'),
  payment_method: z.enum(['CREDIT_CARD', 'PAYPAL', 'BANK_TRANSFER']),
  shipping_method: z.enum(['STANDARD', 'EXPRESS', 'OVERNIGHT']),
  notes: z.string().max(1000, 'Notes are too long').optional(),
  metadata: z.record(z.string(), z.any()).optional()
});

// Customer schemas
export const customerSchema = z.object({
  email: emailSchema,
  first_name: z.string().min(1, 'First name is required'),
  last_name: z.string().min(1, 'Last name is required'),
  phone: phoneSchema.optional(),
  default_address: addressSchema.optional(),
  metadata: z.record(z.string(), z.any()).optional()
});

// Search schemas
export const searchFiltersSchema = z.object({
  categories: z.array(idSchema).optional(),
  minPrice: priceSchema.optional(),
  maxPrice: priceSchema.optional(),
  attributes: z.record(z.string(), z.array(z.string())).optional(),
  inStock: z.boolean().optional()
});

export const sortOptionSchema = z.object({
  field: z.enum(['price', 'created_at', 'name', 'popularity']),
  direction: z.enum(['asc', 'desc'])
});

export const paginationSchema = z.object({
  page: z.number().int().positive().default(1),
  pageSize: z.number().int().min(1).max(100).default(20)
});

// Business logic validation
export const validateOrderItems = (items: z.infer<typeof orderItemSchema>[]) => {
  const uniqueItems = new Set(items.map(item => item.product_id));
  if (uniqueItems.size !== items.length) {
    throw new Error('Duplicate products in order items');
  }
  return true;
};

export const validatePriceRange = (minPrice?: number, maxPrice?: number) => {
  if (minPrice !== undefined && maxPrice !== undefined && minPrice > maxPrice) {
    throw new Error('Minimum price cannot be greater than maximum price');
  }
  return true;
};

// Custom error formatter
export const formatZodError = (error: z.ZodError) => {
  return {
    message: 'Validation failed',
    errors: error.errors.map(err => ({
      field: err.path.join('.'),
      message: err.message
    }))
  };
};