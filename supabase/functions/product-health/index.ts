import { productHealth } from "./health-handler.ts";
import { collectHealth } from "./collect.ts";

Deno.serve((request: Request) => productHealth(request, Deno.env.get("FOOTING_HEALTH_TOKEN"), "footing", () => collectHealth({
  SUPABASE_URL: Deno.env.get("SUPABASE_URL"),
  SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  SUPABASE_SECRET_KEYS: Deno.env.get("SUPABASE_SECRET_KEYS"),
})));
