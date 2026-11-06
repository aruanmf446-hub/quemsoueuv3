import {createCheckoutHandler} from './handler.js';
Deno.serve(createCheckoutHandler({
 gameUrl:Deno.env.get('SUPABASE_URL'), gameKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
 stripeKey:Deno.env.get('STRIPE_SECRET_KEY'), webhookSecret:Deno.env.get('STRIPE_WEBHOOK_SECRET'),
}));
