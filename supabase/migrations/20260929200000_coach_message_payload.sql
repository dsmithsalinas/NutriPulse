-- Structured Pulse replies (docs/daylight-redesign.md): the cards that ride alongside a
-- message's text — one-tap food cards, follow-up chips, the weekly recap card — saved so they
-- survive a reload. `content` keeps the full text, so older app versions and any reader that
-- ignores this column still see a complete message. Nullable and additive: existing rows and
-- clients are untouched, and the owner-only RLS policy already covers the new column.
ALTER TABLE public.coach_messages
  ADD COLUMN IF NOT EXISTS payload JSONB;

-- An object or nothing, and small: the app writes at most three foods, three follow-ups and a
-- four-line recap, so 8 KB is generous while still bounding what a client can store per row.
ALTER TABLE public.coach_messages
  DROP CONSTRAINT IF EXISTS coach_messages_payload_shape;
ALTER TABLE public.coach_messages
  ADD CONSTRAINT coach_messages_payload_shape CHECK (
    payload IS NULL
    OR (jsonb_typeof(payload) = 'object' AND octet_length(payload::text) <= 8192)
  );

COMMENT ON COLUMN public.coach_messages.payload IS
  'Structured Pulse reply extras for assistant messages: {foods?, followUps?, recap?}. Optional; content always holds the full text.';
