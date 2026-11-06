import { createHandler } from './handler.js';
Deno.serve(createHandler({
 gameUrl: Deno.env.get('SUPABASE_URL'),
 gameKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
 catalogUrl: 'https://bsxicvlngphazesuzaee.supabase.co',
 catalogKey: Deno.env.get('CATALOG_SERVICE_ROLE_KEY'),
}));
