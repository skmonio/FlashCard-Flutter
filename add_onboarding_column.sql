-- Add onboarding_completed column to user_profiles table
-- Run this in your Supabase SQL Editor

ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

