-- Test inserting a record to see what RLS error we get
-- This will help us understand exactly what's failing

-- First, let's see the current user
SELECT 'Current user: ' || auth.uid()::text as current_user;

-- Try to insert a test deck
INSERT INTO decks (
    id,
    user_id,
    name,
    parent_id,
    is_public,
    created_at,
    updated_at
) VALUES (
    'test-deck-' || extract(epoch from now())::text,
    auth.uid(),
    'Test Deck',
    null,
    false,
    now(),
    now()
);

-- If that worked, try to insert a test flashcard
INSERT INTO flashcards (
    id,
    user_id,
    word,
    definition,
    is_public,
    created_at,
    updated_at
) VALUES (
    'test-card-' || extract(epoch from now())::text,
    auth.uid(),
    'test',
    'test definition',
    false,
    now(),
    now()
);

-- Clean up test records
DELETE FROM flashcards WHERE word = 'test';
DELETE FROM decks WHERE name = 'Test Deck';

SELECT 'Test completed successfully' as result;

