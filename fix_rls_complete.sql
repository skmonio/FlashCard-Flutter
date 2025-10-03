-- Complete RLS Fix for Taal Trek Dutch Learning App
-- This script will properly enable RLS and set up all necessary policies
-- Run this in your Supabase SQL Editor

-- First, let's check the current state
SELECT 'Current RLS status before changes:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles', 'learning_mastery', 'achievements', 'level_rewards');

-- Check current policies
SELECT 'Current policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles', 'learning_mastery', 'achievements', 'level_rewards');

-- Check if is_public column exists in decks and flashcards tables
SELECT 'Checking for is_public column:' as info;
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name IN ('decks', 'flashcards') 
AND column_name = 'is_public';

-- Add is_public column to decks table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'decks' AND column_name = 'is_public'
    ) THEN
        ALTER TABLE decks ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Added is_public column to decks table';
    ELSE
        RAISE NOTICE 'is_public column already exists in decks table';
    END IF;
END $$;

-- Add is_public column to flashcards table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flashcards' AND column_name = 'is_public'
    ) THEN
        ALTER TABLE flashcards ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Added is_public column to flashcards table';
    ELSE
        RAISE NOTICE 'is_public column already exists in flashcards table';
    END IF;
END $$;

-- Drop all existing policies to start fresh
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- Drop all policies on all tables
    FOR r IN (
        SELECT tablename, policyname 
        FROM pg_policies 
        WHERE tablename IN ('decks', 'flashcards', 'user_profiles', 'learning_mastery', 'achievements', 'level_rewards', 'deck_cards', 'dutch_word_exercises', 'phrases', 'store_packs', 'user_unlocked_packs')
    ) LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON ' || r.tablename;
    END LOOP;
    
    RAISE NOTICE 'Dropped all existing policies';
END $$;

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_mastery ENABLE ROW LEVEL SECURITY;
ALTER TABLE deck_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE dutch_word_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE phrases ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_unlocked_packs ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can view all profiles" ON user_profiles
    FOR SELECT USING (true); -- Allow viewing all profiles for friends feature

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

-- Achievements Policies
CREATE POLICY "Users can view their own achievements" ON achievements
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own achievements" ON achievements
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own achievements" ON achievements
    FOR UPDATE USING (auth.uid() = user_id);

-- Level Rewards Policies
CREATE POLICY "Users can view their own level rewards" ON level_rewards
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own level rewards" ON level_rewards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own level rewards" ON level_rewards
    FOR UPDATE USING (auth.uid() = user_id);

-- Decks Policies
CREATE POLICY "Users can view their own decks" ON decks
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view public decks" ON decks
    FOR SELECT USING (is_public = true);

CREATE POLICY "Users can insert their own decks" ON decks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own decks" ON decks
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own decks" ON decks
    FOR DELETE USING (auth.uid() = user_id);

-- Flashcards Policies
CREATE POLICY "Users can view their own flashcards" ON flashcards
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view public flashcards" ON flashcards
    FOR SELECT USING (is_public = true);

CREATE POLICY "Users can insert their own flashcards" ON flashcards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own flashcards" ON flashcards
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own flashcards" ON flashcards
    FOR DELETE USING (auth.uid() = user_id);

-- Learning Mastery Policies
CREATE POLICY "Users can view their own learning mastery" ON learning_mastery
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own learning mastery" ON learning_mastery
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own learning mastery" ON learning_mastery
    FOR UPDATE USING (auth.uid() = user_id);

-- Deck Cards Policies
CREATE POLICY "Users can view deck cards for their decks" ON deck_cards
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM decks 
            WHERE decks.id = deck_cards.deck_id 
            AND (decks.user_id = auth.uid() OR decks.is_public = true)
        )
    );

CREATE POLICY "Users can manage deck cards for their decks" ON deck_cards
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM decks 
            WHERE decks.id = deck_cards.deck_id 
            AND decks.user_id = auth.uid()
        )
    );

-- Dutch Word Exercises Policies
CREATE POLICY "Users can view their own dutch word exercises" ON dutch_word_exercises
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own dutch word exercises" ON dutch_word_exercises
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own dutch word exercises" ON dutch_word_exercises
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own dutch word exercises" ON dutch_word_exercises
    FOR DELETE USING (auth.uid() = user_id);

-- Phrases Policies
CREATE POLICY "Users can view their own phrases" ON phrases
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own phrases" ON phrases
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own phrases" ON phrases
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own phrases" ON phrases
    FOR DELETE USING (auth.uid() = user_id);

-- Store Packs Policies (public read, admin write)
CREATE POLICY "Anyone can view store packs" ON store_packs
    FOR SELECT USING (true);

-- User Unlocked Packs Policies
CREATE POLICY "Users can view their own unlocked packs" ON user_unlocked_packs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own unlocked packs" ON user_unlocked_packs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create or replace the function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, username, selected_avatar, xp, level)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'Learner'),
        COALESCE(NEW.raw_user_meta_data->>'selected_avatar', 'person'),
        0,
        1
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create user profile (drop first if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Verify RLS is enabled
SELECT 'RLS status after enabling:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles', 'learning_mastery', 'achievements', 'level_rewards');

-- Show all policies that were created
SELECT 'Policies created:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles', 'learning_mastery', 'achievements', 'level_rewards', 'deck_cards', 'dutch_word_exercises', 'phrases', 'store_packs', 'user_unlocked_packs')
ORDER BY tablename, policyname;

-- Test queries to verify policies work
SELECT 'Testing policies - Current user should be able to see their own data:' as info;
SELECT 'Current user ID: ' || COALESCE(auth.uid()::text, 'NULL - not authenticated') as current_user;

-- If authenticated, test access to own data
DO $$
BEGIN
    IF auth.uid() IS NOT NULL THEN
        RAISE NOTICE 'Testing access to user_profiles...';
        PERFORM COUNT(*) FROM user_profiles WHERE id = auth.uid();
        RAISE NOTICE 'Successfully accessed user_profiles';
        
        RAISE NOTICE 'Testing access to decks...';
        PERFORM COUNT(*) FROM decks WHERE user_id = auth.uid();
        RAISE NOTICE 'Successfully accessed decks';
        
        RAISE NOTICE 'Testing access to flashcards...';
        PERFORM COUNT(*) FROM flashcards WHERE user_id = auth.uid();
        RAISE NOTICE 'Successfully accessed flashcards';
    ELSE
        RAISE NOTICE 'Not authenticated - cannot test user-specific access';
    END IF;
END $$;

SELECT 'RLS setup complete! Your tables now have proper security policies.' as result;

