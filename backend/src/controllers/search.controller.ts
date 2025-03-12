import { Response } from 'express';
import { SearchService } from '../services/search.service';
import { AuthenticatedRequest } from '../types/auth';
import { ValidatedRequest } from '../middleware/validate-schema';
import logger from '../config/logger';
import { supabase } from '../config/supabase';
import { z } from 'zod';
import { searchFiltersSchema, sortOptionSchema, paginationSchema } from '../schemas/validation';

// Define the validated search query type
const searchQuerySchema = paginationSchema.extend({
  query: z.string().optional(),
  ...searchFiltersSchema.shape,
  field: z.enum(['price', 'created_at', 'name', 'popularity']).optional(),
  direction: z.enum(['asc', 'desc']).optional()
});

type SearchQuerySchema = z.infer<typeof searchQuerySchema>;

// Define the recommendation params schema
const recommendationParamsSchema = z.object({
  productId: z.string().uuid('Invalid product ID'),
  limit: z.number().int().min(1).max(20).optional()
});

export class SearchController {
  private searchService: SearchService;

  constructor() {
    this.searchService = new SearchService(supabase);
  }

  /**
   * Search products with filtering and facets
   */
  async searchProducts(
    req: ValidatedRequest<SearchQuerySchema> & AuthenticatedRequest,
    res: Response
  ): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      const {
        query,
        categories,
        minPrice,
        maxPrice,
        attributes,
        inStock,
        field,
        direction,
        page,
        pageSize
      } = req.validatedData;

      // Build filters from validated data
      const filters = {
        ...(categories && { categories }),
        ...(minPrice !== undefined && { minPrice }),
        ...(maxPrice !== undefined && { maxPrice }),
        ...(attributes && { attributes }),
        ...(inStock !== undefined && { inStock })
      };

      // Build sort option from validated data
      const sort = field && direction ? { field, direction } : undefined;

      const results = await this.searchService.searchProducts(
        req.user.tenant_id,
        query,
        filters,
        sort,
        page,
        pageSize
      );

      res.json(results);
    } catch (error) {
      logger.error('Error searching products:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }

  /**
   * Get product recommendations
   */
  async getRecommendations(
    req: ValidatedRequest<z.infer<typeof recommendationParamsSchema>> & AuthenticatedRequest,
    res: Response
  ): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      const { productId, limit = 5 } = req.validatedData;

      const recommendations = await this.searchService.getProductRecommendations(
        req.user.tenant_id,
        productId,
        limit
      );

      res.json(recommendations);
    } catch (error) {
      logger.error('Error getting product recommendations:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
}