-- Fix missing columns that are causing copy operations to fail
-- This script adds the missing columns to the database schema

-- Add missing columns to decks table
DO $$ BEGIN
    ALTER TABLE decks ADD COLUMN color BIGINT DEFAULT 4280391411; -- Default blue color
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column color already exists in decks.';
END $$;

DO $$ BEGIN
    ALTER TABLE decks ADD COLUMN icon INTEGER DEFAULT 58968; -- Default folder icon
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column icon already exists in decks.';
END $$;

DO $$ BEGIN
    ALTER TABLE decks ADD COLUMN description TEXT DEFAULT '';
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column description already exists in decks.';
END $$;

-- Add missing columns to flashcards table
DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN best_streak INTEGER DEFAULT 0;
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column best_streak already exists in flashcards.';
END $$;

DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN consecutive_correct INTEGER DEFAULT 0;
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column consecutive_correct already exists in flashcards.';
END $$;

DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN learning_percentage REAL DEFAULT 0.0;
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column learning_percentage already exists in flashcards.';
END $$;

DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN current_hp INTEGER DEFAULT 100;
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column current_hp already exists in flashcards.';
END $$;

DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN max_hp INTEGER DEFAULT 100;
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column max_hp already exists in flashcards.';
END $$;

DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN next_review_date TIMESTAMP WITH TIME ZONE;
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column next_review_date already exists in flashcards.';
END $$;

DO $$ BEGIN
    ALTER TABLE flashcards ADD COLUMN learning_mastery JSONB DEFAULT '{}';
EXCEPTION
    WHEN duplicate_column THEN RAISE NOTICE 'column learning_mastery already exists in flashcards.';
END $$;

-- Verify the columns were added
SELECT 'Decks table columns:' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'decks'
ORDER BY ordinal_position;

SELECT 'Flashcards table columns:' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'flashcards'
ORDER BY ordinal_position;
