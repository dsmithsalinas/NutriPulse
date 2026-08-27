-- Edge Functions now call check_rate_limit_for_user with the service role. Remove the old
-- caller-configurable RPC so authenticated clients cannot choose their own max/window values.
DROP FUNCTION IF EXISTS public.check_rate_limit(TEXT, INTEGER, INTEGER);
