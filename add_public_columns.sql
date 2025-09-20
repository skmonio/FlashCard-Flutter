-- Add is_public columns to existing tables
-- Run these commands in your Supabase SQL Editor

-- Add is_public column to decks table
ALTER TABLE decks ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

-- Add is_public column to flashcards table  
ALTER TABLE flashcards ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

-- Add user_id column to decks table if it doesn't exist (needed for friend queries)
ALTER TABLE decks ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE;

-- Add user_id column to flashcards table if it doesn't exist (needed for friend queries)
ALTER TABLE flashcards ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE;

-- Create indexes for better performance on public queries
CREATE INDEX IF NOT EXISTS idx_decks_is_public ON decks(is_public);
CREATE INDEX IF NOT EXISTS idx_flashcards_is_public ON flashcards(is_public);
CREATE INDEX IF NOT EXISTS idx_decks_user_id ON decks(user_id);
CREATE INDEX IF NOT EXISTS idx_flashcards_user_id ON flashcards(user_id);

-- Update existing records to have default values
UPDATE decks SET is_public = FALSE WHERE is_public IS NULL;
UPDATE flashcards SET is_public = FALSE WHERE is_public IS NULL;
