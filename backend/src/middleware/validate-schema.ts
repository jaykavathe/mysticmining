import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { formatZodError } from '../schemas/validation';
import logger from '../config/logger';

export interface ValidatedRequest<T> extends Request {
  validatedData: T;
}

/**
 * Middleware factory for schema validation
 */
export const validateSchema = <T extends AnyZodObject>(
  schema: T,
  location: 'body' | 'query' | 'params' = 'body'
) => {
  return async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const data = await schema.parseAsync(req[location]);
      (req as ValidatedRequest<T>).validatedData = data;
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        logger.warn('Validation error:', error.errors);
        res.status(400).json(formatZodError(error));
      } else {
        logger.error('Unexpected validation error:', error);
        res.status(500).json({ message: 'Internal server error' });
      }
    }
  };
};

/**
 * Middleware factory for custom business logic validation
 */
export const validateBusinessLogic = (
  validationFn: (data: any) => boolean | Promise<boolean>,
  errorMessage: string
) => {
  return async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const isValid = await validationFn(req.body);
      if (isValid) {
        next();
      } else {
        res.status(400).json({
          message: 'Validation failed',
          errors: [{ message: errorMessage }]
        });
      }
    } catch (error) {
      if (error instanceof Error) {
        logger.warn('Business logic validation error:', error.message);
        res.status(400).json({
          message: 'Validation failed',
          errors: [{ message: error.message }]
        });
      } else {
        logger.error('Unexpected validation error:', error);
        res.status(500).json({ message: 'Internal server error' });
      }
    }
  };
};

/**
 * Middleware for sanitizing user input
 */
export const sanitizeInput = (fields: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    for (const field of fields) {
      if (req.body[field] && typeof req.body[field] === 'string') {
        // Remove HTML tags and trim whitespace
        req.body[field] = req.body[field]
          .replace(/<[^>]*>/g, '')
          .trim();
      }
    }
    next();
  };
};