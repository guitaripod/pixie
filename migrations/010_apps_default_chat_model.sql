-- Per-tenant default chat model. NULL means "use the handler's global
-- DEFAULT_CHAT_MODEL" so existing apps are unaffected. The model id alone
-- selects the provider (gemini-* -> Gemini, gpt-*/o* -> OpenAI) in chat.rs.
ALTER TABLE apps ADD COLUMN default_chat_model TEXT;

-- Psywave moves to gpt-5-mini: cheaper per call than the Gemini default, native
-- vision, and json_object response_format guarantees a valid JSON object for the
-- playlist pipeline. Billing is unaffected (psywave chat.completion is flat 1cr).
UPDATE apps SET default_chat_model = 'gpt-5-mini' WHERE app_id = 'psywave';
