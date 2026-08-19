/**
 * Vercel Web Analytics Integration
 * Initializes Vercel Analytics for the Aura 67 application
 */

import { inject } from '../node_modules/@vercel/analytics/dist/index.mjs';

// Initialize Vercel Web Analytics
inject({
  mode: 'auto', // Automatically detect development/production
  debug: false  // Set to false to reduce console logs in production
});
