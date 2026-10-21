-- ==============================================================================
-- TELEGRAM 2.0 MESSENGER - FULL COMPLETE BACKEND SCHEMA & AUTOMATIONS
-- Idempotent script: Safe to run multiple times without data loss
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure profiles columns exist if upgrading from older schema
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. CHATS TABLE
CREATE TABLE IF NOT EXISTS public.chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('direct', 'group', 'channel')) DEFAULT 'direct',
  title TEXT,
  avatar_url TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  direct_key TEXT UNIQUE,
  last_message_id UUID,
  last_message_text TEXT,
  last_message_sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'direct';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS direct_key TEXT UNIQUE;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_id UUID;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_text TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- 4. CHAT MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.chat_members (
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')) DEFAULT 'member',
  last_read_message_id UUID,
  unread_count INT NOT NULL DEFAULT 0,
  is_muted BOOLEAN NOT NULL DEFAULT FALSE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'member';
ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS last_read_message_id UUID;
ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS unread_count INT NOT NULL DEFAULT 0;
ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ DEFAULT NOW();

-- 5. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT,
  type TEXT NOT NULL CHECK (type IN ('text', 'image', 'voice', 'file', 'video')) DEFAULT 'text',
  media_url TEXT,
  blurhash TEXT,
  duration_sec INT,
  reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  is_edited BOOLEAN NOT NULL DEFAULT FALSE,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS blurhash TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS duration_sec INT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Foreign key for chats.last_message_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_last_message'
  ) THEN
    ALTER TABLE public.chats 
      ADD CONSTRAINT fk_last_message 
      FOREIGN KEY (last_message_id) 
      REFERENCES public.messages(id) 
      ON DELETE SET NULL;
  END IF;
END $$;

-- 6. MESSAGE REACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.message_reactions (
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (message_id, user_id, emoji)
);

-- 7. TYPING INDICATORS TABLE
CREATE TABLE IF NOT EXISTS public.typing_indicators (
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_typing BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

-- 8. PUSH NOTIFICATION TOKENS TABLE
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT CHECK (platform IN ('android', 'ios', 'web')) DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, token)
);

-- 9. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_messages_chat_id_created_at 
  ON public.messages (chat_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_members_user_id 
  ON public.chat_members (user_id);

CREATE INDEX IF NOT EXISTS idx_chats_last_message_at 
  ON public.chats (last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_username 
  ON public.profiles (username);

CREATE INDEX IF NOT EXISTS idx_typing_indicators_chat 
  ON public.typing_indicators (chat_id);

-- ==============================================================================
-- 10. AUTOMATION FUNCTIONS & TRIGGERS
-- ==============================================================================

-- A. Auto-create/sync public.profile when a user registers in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_username TEXT;
  v_display_name TEXT;
  v_avatar_url TEXT;
BEGIN
  v_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    split_part(NEW.email, '@', 1),
    'user_' || SUBSTRING(NEW.id::TEXT, 1, 8)
  );

  v_display_name := COALESCE(
    NEW.raw_user_meta_data->>'display_name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1),
    'Telegram User'
  );

  v_avatar_url := NEW.raw_user_meta_data->>'avatar_url';

  INSERT INTO public.profiles (id, username, display_name, avatar_url)
  VALUES (NEW.id, v_username, v_display_name, v_avatar_url)
  ON CONFLICT (id) DO UPDATE
  SET 
    username = COALESCE(public.profiles.username, EXCLUDED.username),
    display_name = COALESCE(public.profiles.display_name, EXCLUDED.display_name),
    avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url),
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- B. Sync existing auth.users into profiles if any are missing
INSERT INTO public.profiles (id, username, display_name, avatar_url)
SELECT 
  id, 
  COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1), 'user_' || SUBSTRING(id::TEXT, 1, 8)),
  COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'full_name', split_part(email, '@', 1), 'Telegram User'),
  raw_user_meta_data->>'avatar_url'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- C. Trigger on new message: Update chats inbox details and increment unread count for recipients
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. Update chat preview
  UPDATE public.chats
  SET 
    last_message_id = NEW.id,
    last_message_text = CASE 
      WHEN NEW.type = 'image' THEN '📷 Фото'
      WHEN NEW.type = 'voice' THEN '🎤 Голосовое сообщение'
      WHEN NEW.type = 'file' THEN '📎 Файл'
      WHEN NEW.type = 'video' THEN '🎥 Видео'
      ELSE COALESCE(NEW.content, '')
    END,
    last_message_sender_id = NEW.sender_id,
    last_message_at = NEW.created_at
  WHERE id = NEW.chat_id;

  -- 2. Increment unread count for all members except sender
  UPDATE public.chat_members
  SET unread_count = COALESCE(unread_count, 0) + 1
  WHERE chat_id = NEW.chat_id AND user_id != NEW.sender_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_created ON public.messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_message();

-- D. Mark chat as read: resets unread count and marks incoming messages with double checkmarks (is_read = TRUE)
CREATE OR REPLACE FUNCTION public.mark_chat_as_read(p_chat_id UUID, p_message_id UUID DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
  -- 1. Reset reader's unread counter
  UPDATE public.chat_members
  SET 
    last_read_message_id = COALESCE(p_message_id, last_read_message_id),
    unread_count = 0
  WHERE chat_id = p_chat_id AND user_id = auth.uid();

  -- 2. Mark partner messages as read
  UPDATE public.messages
  SET is_read = TRUE
  WHERE chat_id = p_chat_id 
    AND sender_id != auth.uid()
    AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- E. Create or get direct chat between current user and target user
CREATE OR REPLACE FUNCTION public.get_or_create_direct_chat(target_user_id UUID)
RETURNS UUID AS $$
DECLARE
  v_chat_id UUID;
  v_key TEXT;
  v_my_id UUID := auth.uid();
BEGIN
  IF v_my_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_my_id = target_user_id THEN
    RAISE EXCEPTION 'Cannot create direct chat with yourself';
  END IF;

  -- Generate canonical key
  IF v_my_id < target_user_id THEN
    v_key := v_my_id::TEXT || '_' || target_user_id::TEXT;
  ELSE
    v_key := target_user_id::TEXT || '_' || v_my_id::TEXT;
  END IF;

  -- Check existing chat
  SELECT id INTO v_chat_id FROM public.chats WHERE direct_key = v_key LIMIT 1;
  
  IF v_chat_id IS NOT NULL THEN
    INSERT INTO public.chat_members (chat_id, user_id, role)
    VALUES 
      (v_chat_id, v_my_id, 'member'),
      (v_chat_id, target_user_id, 'member')
    ON CONFLICT (chat_id, user_id) DO NOTHING;

    RETURN v_chat_id;
  END IF;

  -- Create new direct chat
  INSERT INTO public.chats (type, direct_key, created_by)
  VALUES ('direct', v_key, v_my_id)
  RETURNING id INTO v_chat_id;

  INSERT INTO public.chat_members (chat_id, user_id, role)
  VALUES 
    (v_chat_id, v_my_id, 'member'),
    (v_chat_id, target_user_id, 'member')
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  RETURN v_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- F. Helper function: check chat membership without recursive RLS
CREATE OR REPLACE FUNCTION public.is_chat_member(p_chat_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE chat_id = p_chat_id AND user_id = p_user_id
  );
$$;

-- G. Presence & typing helpers
CREATE OR REPLACE FUNCTION public.set_user_presence(p_is_online BOOLEAN)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET 
    is_online = p_is_online,
    last_seen = NOW()
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.set_typing(p_chat_id UUID, p_is_typing BOOLEAN)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.typing_indicators (chat_id, user_id, is_typing, updated_at)
  VALUES (p_chat_id, auth.uid(), p_is_typing, NOW())
  ON CONFLICT (chat_id, user_id) DO UPDATE
  SET 
    is_typing = EXCLUDED.is_typing,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 11. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Profiles viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles viewable by authenticated users"
  ON public.profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Chat Members Policies
DROP POLICY IF EXISTS "Chat members viewable by authenticated users" ON public.chat_members;
CREATE POLICY "Chat members viewable by authenticated users"
  ON public.chat_members FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert chat members" ON public.chat_members;
CREATE POLICY "Users can insert chat members"
  ON public.chat_members FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own member settings" ON public.chat_members;
CREATE POLICY "Users can update their own member settings"
  ON public.chat_members FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- Chats Policies
DROP POLICY IF EXISTS "Users can view chats they belong to" ON public.chats;
CREATE POLICY "Users can view chats they belong to"
  ON public.chats FOR SELECT TO authenticated USING (public.is_chat_member(id, auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can create chats" ON public.chats;
CREATE POLICY "Authenticated users can create chats"
  ON public.chats FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Members can update chats" ON public.chats;
CREATE POLICY "Members can update chats"
  ON public.chats FOR UPDATE TO authenticated USING (public.is_chat_member(id, auth.uid()));

-- Messages Policies
DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.messages;
CREATE POLICY "Users can view messages in their chats"
  ON public.messages FOR SELECT TO authenticated USING (public.is_chat_member(chat_id, auth.uid()));

DROP POLICY IF EXISTS "Users can insert messages into their chats" ON public.messages;
CREATE POLICY "Users can insert messages into their chats"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = sender_id AND
    public.is_chat_member(chat_id, auth.uid())
  );

DROP POLICY IF EXISTS "Members can update messages" ON public.messages;
CREATE POLICY "Members can update messages"
  ON public.messages FOR UPDATE TO authenticated
  USING (public.is_chat_member(chat_id, auth.uid()));

-- Message Reactions Policies
DROP POLICY IF EXISTS "Members can view reactions" ON public.message_reactions;
CREATE POLICY "Members can view reactions"
  ON public.message_reactions FOR SELECT TO authenticated
  USING (
    public.is_chat_member(
      (SELECT chat_id FROM public.messages WHERE id = message_reactions.message_id),
      auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can manage their own reactions" ON public.message_reactions;
CREATE POLICY "Users can manage their own reactions"
  ON public.message_reactions FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Typing Indicators Policies
DROP POLICY IF EXISTS "Members can view typing indicators" ON public.typing_indicators;
CREATE POLICY "Members can view typing indicators"
  ON public.typing_indicators FOR SELECT TO authenticated
  USING (public.is_chat_member(chat_id, auth.uid()));

DROP POLICY IF EXISTS "Users can set their own typing indicator" ON public.typing_indicators;
CREATE POLICY "Users can set their own typing indicator"
  ON public.typing_indicators FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Push Tokens Policies
DROP POLICY IF EXISTS "Users can manage their push tokens" ON public.user_push_tokens;
CREATE POLICY "Users can manage their push tokens"
  ON public.user_push_tokens FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ==============================================================================
-- 12. PERMISSIONS GRANT
-- ==============================================================================
GRANT EXECUTE ON FUNCTION public.mark_chat_as_read(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_chat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_chat_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_presence(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_typing(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_message() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;

-- ==============================================================================
-- 13. REALTIME PUBLICATION
-- ==============================================================================
-- Enable publication of changes to real-time client subscribers
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_members;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_indicators;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
