-- Force disable RLS completely to test sync functionality
-- This will allow all authenticated users to access all data
-- WARNING: Only use for testing!

-- First, let's see what's currently enabled
SELECT 'Current RLS status before changes:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

-- Disable RLS completely
ALTER TABLE decks DISABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- Drop ALL policies (including any that might be hidden or named differently)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- Drop all policies on decks table
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'decks') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON decks';
    END LOOP;
    
    -- Drop all policies on flashcards table
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'flashcards') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON flashcards';
    END LOOP;
    
    -- Drop all policies on user_profiles table
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'user_profiles') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON user_profiles';
    END LOOP;
END $$;

-- Verify RLS is completely disabled
SELECT 'RLS status after disabling:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

-- Verify no policies remain
SELECT 'Remaining policies (should be empty):' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles');

-- Test if we can query the tables
SELECT 'Testing table access:' as info;
SELECT 'decks table accessible: ' || (SELECT COUNT(*) FROM decks)::text as decks_count;
SELECT 'flashcards table accessible: ' || (SELECT COUNT(*) FROM flashcards)::text as flashcards_count;
SELECT 'user_profiles table accessible: ' || (SELECT COUNT(*) FROM user_profiles)::text as profiles_count;
