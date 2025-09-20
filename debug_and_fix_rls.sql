-- Debug and fix RLS policies for decks and flashcards tables
-- This script includes debugging queries to help identify issues

-- First, let's check the current state of the tables and policies
SELECT 'Current RLS status:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

SELECT 'Current policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

-- Check if the columns exist
SELECT 'Table columns:' as info;
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name IN ('decks', 'flashcards', 'user_profiles')
ORDER BY table_name, ordinal_position;

-- Disable RLS temporarily to test
ALTER TABLE decks DISABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Users can view their own decks" ON decks;
DROP POLICY IF EXISTS "Users can insert their own decks" ON decks;
DROP POLICY IF EXISTS "Users can update their own decks" ON decks;
DROP POLICY IF EXISTS "Users can delete their own decks" ON decks;
DROP POLICY IF EXISTS "Users can view public decks" ON decks;

DROP POLICY IF EXISTS "Users can view their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can insert their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can update their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can delete their own flashcards" ON flashcards;
DROP POLICY IF EXISTS "Users can view public flashcards" ON flashcards;

DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view public profiles" ON user_profiles;

-- Re-enable RLS
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create comprehensive policies for decks table
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

-- Create comprehensive policies for flashcards table
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

-- Create comprehensive policies for user_profiles table
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view public profiles" ON user_profiles
    FOR SELECT USING (true); -- Allow viewing all profiles for friends feature

-- Test the policies by checking if we can query the tables
SELECT 'Testing policies - should show current user data:' as info;
SELECT 'Current user ID: ' || auth.uid() as current_user;

-- Show final policy status
SELECT 'Final RLS status:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

SELECT 'Final policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

