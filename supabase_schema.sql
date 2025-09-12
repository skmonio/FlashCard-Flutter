-- Supabase Database Schema for Taal Trek Dutch Learning App
-- Run these commands in your Supabase SQL Editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE achievement_type AS ENUM ('xp', 'level', 'streak', 'sessions', 'perfect', 'accuracy');
CREATE TYPE level_reward_type AS ENUM ('xp', 'streak', 'feature', 'cosmetic');
CREATE TYPE learning_state AS ENUM ('new', 'learning', 'reviewing', 'mastered', 'expert');
CREATE TYPE game_difficulty AS ENUM ('easy', 'medium', 'hard', 'expert');

-- User Profiles Table
CREATE TABLE user_profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT NOT NULL DEFAULT 'Learner',
    selected_avatar TEXT NOT NULL DEFAULT 'person',
    profile_image_data TEXT,
    xp INTEGER NOT NULL DEFAULT 0,
    level INTEGER NOT NULL DEFAULT 1,
    total_sessions INTEGER NOT NULL DEFAULT 0,
    current_streak INTEGER NOT NULL DEFAULT 0,
    best_streak INTEGER NOT NULL DEFAULT 0,
    accuracy DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    total_cards_studied INTEGER NOT NULL DEFAULT 0,
    perfect_sessions INTEGER NOT NULL DEFAULT 0,
    last_study_date TIMESTAMPTZ,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Achievements Table
CREATE TABLE achievements (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    xp_required INTEGER NOT NULL DEFAULT 0,
    level_required INTEGER NOT NULL DEFAULT 0,
    type achievement_type NOT NULL,
    is_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
    unlocked_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Level Rewards Table
CREATE TABLE level_rewards (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    level INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    type level_reward_type NOT NULL,
    value INTEGER NOT NULL,
    is_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Decks Table
CREATE TABLE decks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    parent_id UUID REFERENCES decks(id) ON DELETE CASCADE,
    is_system_deck BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sub-decks relationship table
CREATE TABLE deck_hierarchy (
    parent_id UUID REFERENCES decks(id) ON DELETE CASCADE,
    child_id UUID REFERENCES decks(id) ON DELETE CASCADE,
    PRIMARY KEY (parent_id, child_id)
);

-- Flashcards Table
CREATE TABLE flashcards (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    word TEXT NOT NULL,
    definition TEXT NOT NULL DEFAULT '',
    example TEXT NOT NULL DEFAULT '',
    example_translation TEXT NOT NULL DEFAULT '',
    article TEXT NOT NULL DEFAULT '',
    plural TEXT NOT NULL DEFAULT '',
    past_tense TEXT NOT NULL DEFAULT '',
    future_tense TEXT NOT NULL DEFAULT '',
    past_participle TEXT NOT NULL DEFAULT '',
    success_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Learning Mastery Table (stores the complex learning data)
CREATE TABLE learning_mastery (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    flashcard_id UUID REFERENCES flashcards(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Game-specific correct answers
    easy_correct INTEGER NOT NULL DEFAULT 0,
    medium_correct INTEGER NOT NULL DEFAULT 0,
    hard_correct INTEGER NOT NULL DEFAULT 0,
    expert_correct INTEGER NOT NULL DEFAULT 0,
    
    -- Game-specific total attempts
    easy_attempts INTEGER NOT NULL DEFAULT 0,
    medium_attempts INTEGER NOT NULL DEFAULT 0,
    hard_attempts INTEGER NOT NULL DEFAULT 0,
    expert_attempts INTEGER NOT NULL DEFAULT 0,
    
    -- SuperMemo SM-2 specific fields
    repetitions INTEGER NOT NULL DEFAULT 0,
    lapses INTEGER NOT NULL DEFAULT 0,
    interval INTEGER NOT NULL DEFAULT 1,
    
    -- Legacy SRS fields
    last_review_date TIMESTAMPTZ,
    consecutive_correct INTEGER NOT NULL DEFAULT 0,
    consecutive_incorrect INTEGER NOT NULL DEFAULT 0,
    ease_factor DECIMAL(4,2) NOT NULL DEFAULT 2.5,
    srs_level INTEGER NOT NULL DEFAULT 0,
    next_review_date TIMESTAMPTZ,
    total_reviews INTEGER NOT NULL DEFAULT 0,
    
    -- RPG-style leveling system
    current_xp INTEGER NOT NULL DEFAULT 0,
    current_level INTEGER NOT NULL DEFAULT 0,
    current_hp INTEGER NOT NULL DEFAULT 100,
    max_hp INTEGER NOT NULL DEFAULT 100,
    
    -- Daily tracking
    daily_game_attempts JSONB NOT NULL DEFAULT '{}',
    last_game_reset_date TIMESTAMPTZ,
    times_studied_today INTEGER NOT NULL DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(flashcard_id, user_id)
);

-- Level up history table
CREATE TABLE level_up_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    learning_mastery_id UUID REFERENCES learning_mastery(id) ON DELETE CASCADE NOT NULL,
    level INTEGER NOT NULL,
    xp_gained INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Exercise history table
CREATE TABLE exercise_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    learning_mastery_id UUID REFERENCES learning_mastery(id) ON DELETE CASCADE NOT NULL,
    exercise_type TEXT NOT NULL,
    difficulty game_difficulty NOT NULL,
    xp_gained INTEGER NOT NULL,
    is_correct BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deck-Card relationship table (many-to-many)
CREATE TABLE deck_cards (
    deck_id UUID REFERENCES decks(id) ON DELETE CASCADE,
    flashcard_id UUID REFERENCES flashcards(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (deck_id, flashcard_id)
);

-- Dutch Word Exercises Table
CREATE TABLE dutch_word_exercises (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    target_word TEXT NOT NULL,
    exercises JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Phrases Table
CREATE TABLE phrases (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    dutch_text TEXT NOT NULL,
    english_translation TEXT NOT NULL,
    context TEXT,
    difficulty_level INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Store Packs Table
CREATE TABLE store_packs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price INTEGER NOT NULL DEFAULT 0,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    pack_data JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Unlocked Packs Table
CREATE TABLE user_unlocked_packs (
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    pack_id UUID REFERENCES store_packs(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, pack_id)
);

-- Create indexes for better performance
CREATE INDEX idx_user_profiles_user_id ON user_profiles(id);
CREATE INDEX idx_achievements_user_id ON achievements(user_id);
CREATE INDEX idx_level_rewards_user_id ON level_rewards(user_id);
CREATE INDEX idx_decks_user_id ON decks(user_id);
CREATE INDEX idx_flashcards_user_id ON flashcards(user_id);
CREATE INDEX idx_flashcards_word ON flashcards(word);
CREATE INDEX idx_learning_mastery_flashcard_id ON learning_mastery(flashcard_id);
CREATE INDEX idx_learning_mastery_user_id ON learning_mastery(user_id);
CREATE INDEX idx_learning_mastery_next_review ON learning_mastery(next_review_date);
CREATE INDEX idx_deck_cards_deck_id ON deck_cards(deck_id);
CREATE INDEX idx_deck_cards_flashcard_id ON deck_cards(flashcard_id);
CREATE INDEX idx_dutch_word_exercises_user_id ON dutch_word_exercises(user_id);
CREATE INDEX idx_phrases_user_id ON phrases(user_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_decks_updated_at BEFORE UPDATE ON decks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_flashcards_updated_at BEFORE UPDATE ON flashcards FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_learning_mastery_updated_at BEFORE UPDATE ON learning_mastery FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_dutch_word_exercises_updated_at BEFORE UPDATE ON dutch_word_exercises FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_phrases_updated_at BEFORE UPDATE ON phrases FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_store_packs_updated_at BEFORE UPDATE ON store_packs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
