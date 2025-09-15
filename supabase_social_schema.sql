-- Social Features Database Schema for Taal Trek Dutch Learning App
-- Run these commands in your Supabase SQL Editor

-- Friends Table
CREATE TABLE friends (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    friend_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, friend_id)
);

-- Friend Requests Table (for better tracking)
CREATE TABLE friend_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    sender_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(sender_id, receiver_id)
);

-- Study Sessions Table (for group study)
CREATE TABLE study_sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    host_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    deck_id UUID REFERENCES decks(id) ON DELETE SET NULL,
    max_participants INTEGER DEFAULT 10,
    is_public BOOLEAN DEFAULT TRUE,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
    scheduled_at TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Study Session Participants
CREATE TABLE study_session_participants (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    session_id UUID REFERENCES study_sessions(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    score INTEGER DEFAULT 0,
    UNIQUE(session_id, user_id)
);

-- Public Decks Table (for sharing)
CREATE TABLE public_decks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    original_deck_id UUID REFERENCES decks(id) ON DELETE CASCADE NOT NULL,
    creator_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    tags TEXT[],
    is_featured BOOLEAN DEFAULT FALSE,
    download_count INTEGER DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deck Reviews
CREATE TABLE deck_reviews (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    deck_id UUID REFERENCES public_decks(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(deck_id, user_id)
);

-- User Activity Feed
CREATE TABLE user_activities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('achievement', 'level_up', 'streak', 'deck_shared', 'study_completed')),
    title TEXT NOT NULL,
    description TEXT,
    metadata JSONB,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications Table
CREATE TABLE notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('friend_request', 'friend_accepted', 'study_invite', 'achievement', 'level_up')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_friends_user_id ON friends(user_id);
CREATE INDEX idx_friends_friend_id ON friends(friend_id);
CREATE INDEX idx_friends_status ON friends(status);

CREATE INDEX idx_friend_requests_sender ON friend_requests(sender_id);
CREATE INDEX idx_friend_requests_receiver ON friend_requests(receiver_id);
CREATE INDEX idx_friend_requests_status ON friend_requests(status);

CREATE INDEX idx_study_sessions_host ON study_sessions(host_id);
CREATE INDEX idx_study_sessions_status ON study_sessions(status);
CREATE INDEX idx_study_sessions_scheduled ON study_sessions(scheduled_at);

CREATE INDEX idx_public_decks_creator ON public_decks(creator_id);
CREATE INDEX idx_public_decks_featured ON public_decks(is_featured);
CREATE INDEX idx_public_decks_rating ON public_decks(rating DESC);

CREATE INDEX idx_user_activities_user ON user_activities(user_id);
CREATE INDEX idx_user_activities_type ON user_activities(activity_type);
CREATE INDEX idx_user_activities_created ON user_activities(created_at DESC);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- Row Level Security (RLS) Policies

-- Friends policies
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own friends" ON friends
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users can add friends" ON friends
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own friend relationships" ON friends
    FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users can delete their own friend relationships" ON friends
    FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Friend requests policies
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own friend requests" ON friend_requests
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users can send friend requests" ON friend_requests
    FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users can respond to friend requests" ON friend_requests
    FOR UPDATE USING (auth.uid() = receiver_id);

-- Study sessions policies
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view public study sessions" ON study_sessions
    FOR SELECT USING (is_public = true OR auth.uid() = host_id);
CREATE POLICY "Users can create study sessions" ON study_sessions
    FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "Hosts can update their study sessions" ON study_sessions
    FOR UPDATE USING (auth.uid() = host_id);

-- Study session participants policies
ALTER TABLE study_session_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view session participants" ON study_session_participants
    FOR SELECT USING (true); -- Allow viewing for public sessions
CREATE POLICY "Users can join study sessions" ON study_session_participants
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave study sessions" ON study_session_participants
    FOR DELETE USING (auth.uid() = user_id);

-- Public decks policies
ALTER TABLE public_decks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view public decks" ON public_decks
    FOR SELECT USING (true);
CREATE POLICY "Users can create public decks" ON public_decks
    FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Creators can update their public decks" ON public_decks
    FOR UPDATE USING (auth.uid() = creator_id);

-- Deck reviews policies
ALTER TABLE deck_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view deck reviews" ON deck_reviews
    FOR SELECT USING (true);
CREATE POLICY "Users can create deck reviews" ON deck_reviews
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own reviews" ON deck_reviews
    FOR UPDATE USING (auth.uid() = user_id);

-- User activities policies
ALTER TABLE user_activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view public activities" ON user_activities
    FOR SELECT USING (is_public = true OR auth.uid() = user_id);
CREATE POLICY "Users can create their own activities" ON user_activities
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Notifications policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Functions for common operations

-- Function to get user's friends
CREATE OR REPLACE FUNCTION get_user_friends(user_uuid UUID)
RETURNS TABLE (
    friend_id UUID,
    username TEXT,
    selected_avatar TEXT,
    level INTEGER,
    xp INTEGER,
    current_streak INTEGER,
    last_activity TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.friend_id,
        up.username,
        up.selected_avatar,
        up.level,
        up.xp,
        up.current_streak,
        up.updated_at as last_activity
    FROM friends f
    JOIN user_profiles up ON f.friend_id = up.id
    WHERE f.user_id = user_uuid AND f.status = 'accepted'
    ORDER BY up.xp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get leaderboard
CREATE OR REPLACE FUNCTION get_leaderboard(limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
    rank BIGINT,
    user_id UUID,
    username TEXT,
    selected_avatar TEXT,
    level INTEGER,
    xp INTEGER,
    current_streak INTEGER,
    total_sessions INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY up.xp DESC, up.level DESC) as rank,
        up.id as user_id,
        up.username,
        up.selected_avatar,
        up.level,
        up.xp,
        up.current_streak,
        up.total_sessions
    FROM user_profiles up
    ORDER BY up.xp DESC, up.level DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's rank
CREATE OR REPLACE FUNCTION get_user_rank(user_uuid UUID)
RETURNS TABLE (
    rank BIGINT,
    total_users BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        user_rank.rank,
        total_users.count
    FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY xp DESC, level DESC) as rank
        FROM user_profiles
        WHERE id = user_uuid
    ) user_rank
    CROSS JOIN (
        SELECT COUNT(*) as count FROM user_profiles
    ) total_users;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
