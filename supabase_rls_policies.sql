-- Row Level Security (RLS) Policies for Taal Trek Dutch Learning App
-- Run these commands in your Supabase SQL Editor AFTER creating the tables

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE deck_hierarchy ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_mastery ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_up_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE deck_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE dutch_word_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE phrases ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_unlocked_packs ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

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

CREATE POLICY "Users can insert their own decks" ON decks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own decks" ON decks
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own decks" ON decks
    FOR DELETE USING (auth.uid() = user_id);

-- Deck Hierarchy Policies
CREATE POLICY "Users can view deck hierarchy for their decks" ON deck_hierarchy
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM decks 
            WHERE decks.id = deck_hierarchy.parent_id 
            AND decks.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can manage deck hierarchy for their decks" ON deck_hierarchy
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM decks 
            WHERE decks.id = deck_hierarchy.parent_id 
            AND decks.user_id = auth.uid()
        )
    );

-- Flashcards Policies
CREATE POLICY "Users can view their own flashcards" ON flashcards
    FOR SELECT USING (auth.uid() = user_id);

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

-- Level Up History Policies
CREATE POLICY "Users can view their own level up history" ON level_up_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM learning_mastery 
            WHERE learning_mastery.id = level_up_history.learning_mastery_id 
            AND learning_mastery.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert their own level up history" ON level_up_history
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM learning_mastery 
            WHERE learning_mastery.id = level_up_history.learning_mastery_id 
            AND learning_mastery.user_id = auth.uid()
        )
    );

-- Exercise History Policies
CREATE POLICY "Users can view their own exercise history" ON exercise_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM learning_mastery 
            WHERE learning_mastery.id = exercise_history.learning_mastery_id 
            AND learning_mastery.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert their own exercise history" ON exercise_history
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM learning_mastery 
            WHERE learning_mastery.id = exercise_history.learning_mastery_id 
            AND learning_mastery.user_id = auth.uid()
        )
    );

-- Deck Cards Policies
CREATE POLICY "Users can view deck cards for their decks" ON deck_cards
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM decks 
            WHERE decks.id = deck_cards.deck_id 
            AND decks.user_id = auth.uid()
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

-- Create a function to automatically create user profile on signup
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

-- Create trigger to automatically create user profile
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

