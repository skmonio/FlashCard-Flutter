-- Fix Row Level Security policies for decks and flashcards tables
-- This script ensures users can insert, update, and select their own data

-- Enable RLS on decks table if not already enabled
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own decks" ON decks;
DROP POLICY IF EXISTS "Users can insert their own decks" ON decks;
DROP POLICY IF EXISTS "Users can update their own decks" ON decks;
DROP POLICY IF EXISTS "Users can delete their own decks" ON decks;
DROP POLICY IF EXISTS "Users can view public decks" ON decks;

-- Create policies for decks table
CREATE POLICY "Users can view their own decks" ON decks
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own decks" ON decks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own decks" ON decks
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own decks" ON decks
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view public decks" ON decks
    FOR SELECT USING (is_public = true);

-- Enable RLS on flashcards table if not already enabled
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can insert their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can update their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can delete their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can view public flashcards" ON flashcards;

-- Create policies for flashcards table
CREATE POLICY "Users can view their own flashcards" ON flashcards
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own flashcards" ON flashcards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own flashcards" ON flashcards
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own flashcards" ON flashcards
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view public flashcards" ON flashcards
    FOR SELECT USING (is_public = true);

-- Also ensure user_profiles table has proper RLS policies
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view public profiles" ON user_profiles;

-- Create policies for user_profiles table
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view public profiles" ON user_profiles
    FOR SELECT USING (true); -- Allow viewing all profiles for friends feature

