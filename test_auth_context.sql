-- Test authentication context and RLS policies
-- Run this to understand what's happening with auth.uid()

-- Check current authentication context
SELECT 'Authentication context:' as info;
SELECT 
    'Current user ID: ' || COALESCE(auth.uid()::text, 'NULL') as current_user,
    'Is authenticated: ' || COALESCE(auth.role()::text, 'NULL') as auth_role;

-- Check if the user exists in auth.users
SELECT 'User in auth.users:' as info;
SELECT 
    id,
    email,
    created_at,
    email_confirmed_at,
    last_sign_in_at
FROM auth.users 
WHERE id = auth.uid();

-- Check if the user has a profile
SELECT 'User profile:' as info;
SELECT 
    id,
    username,
    level,
    xp,
    created_at
FROM user_profiles 
WHERE id = auth.uid();

-- Test RLS policies by trying to select from tables
SELECT 'Testing RLS policies:' as info;

-- Test decks table
SELECT 'decks table test:' as info;
SELECT COUNT(*) as deck_count FROM decks;

-- Test flashcards table  
SELECT 'flashcards table test:' as info;
SELECT COUNT(*) as flashcard_count FROM flashcards;

-- Test user_profiles table
SELECT 'user_profiles table test:' as info;
SELECT COUNT(*) as profile_count FROM user_profiles;

-- Check what policies exist
SELECT 'Current policies:' as info;
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('decks', 'flashcards', 'user_profiles')
ORDER BY tablename, policyname;

