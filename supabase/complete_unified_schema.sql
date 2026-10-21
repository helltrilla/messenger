-- ==============================================================================
-- TELEGRAM 2.0 MESSENGER - COMPLETE UNIFIED BACKEND SCHEMA
-- ==============================================================================
-- Run this entire script in Supabase SQL Editor in ONE GO.
-- Fully idempotent (safe to re-run multiple times).
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. CHATS TABLE
CREATE TABLE IF NOT EXISTS public.chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('direct', 'group', 'channel', 'saved')) DEFAULT 'direct',
  title TEXT,
  avatar_url TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  direct_key TEXT UNIQUE,
  pinned_message_id UUID,
  last_message_id UUID,
  last_message_text TEXT,
  last_message_sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chats DROP CONSTRAINT IF EXISTS chats_type_check;
ALTER TABLE public.chats ADD CONSTRAINT chats_type_check CHECK (type IN ('direct', 'group', 'channel', 'saved'));

ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'direct';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS direct_key TEXT UNIQUE;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS pinned_message_id UUID;
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
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  last_read_message_id UUID,
  unread_count INT NOT NULL DEFAULT 0,
  is_muted BOOLEAN NOT NULL DEFAULT FALSE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'member';
ALTER TABLE public.chat_members ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;
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
  forward_from_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
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
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS forward_from_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Ensure REPLICA IDENTITY FULL for Supabase Realtime
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- Foreign key constraints for chats
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_last_message') THEN
    ALTER TABLE public.chats 
      ADD CONSTRAINT fk_last_message 
      FOREIGN KEY (last_message_id) 
      REFERENCES public.messages(id) 
      ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pinned_message') THEN
    ALTER TABLE public.chats 
      ADD CONSTRAINT fk_pinned_message 
      FOREIGN KEY (pinned_message_id) 
      REFERENCES public.messages(id) 
      ON DELETE SET NULL;
  END IF;
END $$;

-- 6. MESSAGE REACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id, emoji)
);

ALTER TABLE public.message_reactions REPLICA IDENTITY FULL;

-- 7. TYPING INDICATORS TABLE
CREATE TABLE IF NOT EXISTS public.typing_indicators (
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_typing BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE public.typing_indicators REPLICA IDENTITY FULL;

-- 8. PUSH NOTIFICATION TOKENS TABLE
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT CHECK (platform IN ('android', 'ios', 'web')) DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, token)
);

-- 9. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_messages_chat_id_created_at ON public.messages (chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON public.chat_members (user_id);
CREATE INDEX IF NOT EXISTS idx_chats_last_message_at ON public.chats (last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles (username);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_chat ON public.typing_indicators (chat_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_message ON public.message_reactions (message_id);

-- GIN trigram index for fast message searching
CREATE INDEX IF NOT EXISTS idx_messages_content_trgm ON public.messages USING gin (content gin_trgm_ops);

-- ==============================================================================
-- 10. AUTOMATION FUNCTIONS & TRIGGERS
-- ==============================================================================

-- A. Auto-create/sync profile when user signs up
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

-- Sync existing users
INSERT INTO public.profiles (id, username, display_name, avatar_url)
SELECT 
  id, 
  COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1), 'user_' || SUBSTRING(id::TEXT, 1, 8)),
  COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'full_name', split_part(email, '@', 1), 'Telegram User'),
  raw_user_meta_data->>'avatar_url'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- B. Handle new message: update chat preview & increment unread counts
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
BEGIN
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

-- C. Handle message deleted: recalculate last message in chat
CREATE OR REPLACE FUNCTION public.handle_message_deleted()
RETURNS TRIGGER AS $$
DECLARE
  v_last_msg RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM public.chats WHERE id = OLD.chat_id AND last_message_id = OLD.id) THEN
    SELECT id, content, type, sender_id, created_at
    INTO v_last_msg
    FROM public.messages
    WHERE chat_id = OLD.chat_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      UPDATE public.chats
      SET
        last_message_id = v_last_msg.id,
        last_message_text = CASE 
          WHEN v_last_msg.type = 'image' THEN '📷 Фото'
          WHEN v_last_msg.type = 'voice' THEN '🎤 Голосовое сообщение'
          WHEN v_last_msg.type = 'file' THEN '📎 Файл'
          WHEN v_last_msg.type = 'video' THEN '🎥 Видео'
          ELSE COALESCE(v_last_msg.content, '')
        END,
        last_message_sender_id = v_last_msg.sender_id,
        last_message_at = v_last_msg.created_at
      WHERE id = OLD.chat_id;
    ELSE
      UPDATE public.chats
      SET
        last_message_id = NULL,
        last_message_text = NULL,
        last_message_sender_id = NULL,
        last_message_at = NULL
      WHERE id = OLD.chat_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_deleted ON public.messages;
CREATE TRIGGER on_message_deleted
  AFTER DELETE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_deleted();

-- D. Handle message updated: update chat last_message_text if editing last message
CREATE OR REPLACE FUNCTION public.handle_message_updated()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content IS DISTINCT FROM OLD.content THEN
    UPDATE public.chats
    SET 
      last_message_text = CASE 
        WHEN NEW.type = 'image' THEN '📷 Фото'
        WHEN NEW.type = 'voice' THEN '🎤 Голосовое сообщение'
        WHEN NEW.type = 'file' THEN '📎 Файл'
        WHEN NEW.type = 'video' THEN '🎥 Видео'
        ELSE COALESCE(NEW.content, '')
      END
    WHERE id = NEW.chat_id AND last_message_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_updated ON public.messages;
CREATE TRIGGER on_message_updated
  AFTER UPDATE OF content ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_updated();

-- E. Mark chat as read
CREATE OR REPLACE FUNCTION public.mark_chat_as_read(p_chat_id UUID, p_message_id UUID DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.chat_members
  SET 
    last_read_message_id = COALESCE(p_message_id, last_read_message_id),
    unread_count = 0
  WHERE chat_id = p_chat_id AND user_id = auth.uid();

  UPDATE public.messages
  SET is_read = TRUE
  WHERE chat_id = p_chat_id 
    AND sender_id != auth.uid()
    AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- F. Get or create direct chat
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

  IF v_my_id < target_user_id THEN
    v_key := v_my_id::TEXT || '_' || target_user_id::TEXT;
  ELSE
    v_key := target_user_id::TEXT || '_' || v_my_id::TEXT;
  END IF;

  SELECT id INTO v_chat_id FROM public.chats WHERE direct_key = v_key LIMIT 1;
  
  IF v_chat_id IS NOT NULL THEN
    INSERT INTO public.chat_members (chat_id, user_id, role)
    VALUES 
      (v_chat_id, v_my_id, 'member'),
      (v_chat_id, target_user_id, 'member')
    ON CONFLICT (chat_id, user_id) DO NOTHING;

    RETURN v_chat_id;
  END IF;

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

-- G. Create group chat
CREATE OR REPLACE FUNCTION public.create_group_chat(p_title TEXT, p_member_ids UUID[])
RETURNS UUID AS $$
DECLARE
  v_chat_id UUID;
  v_my_id UUID := auth.uid();
  v_member_id UUID;
BEGIN
  IF v_my_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.chats (type, title, created_by)
  VALUES ('group', p_title, v_my_id)
  RETURNING id INTO v_chat_id;

  -- Add creator as owner
  INSERT INTO public.chat_members (chat_id, user_id, role)
  VALUES (v_chat_id, v_my_id, 'owner');

  -- Add members
  FOREACH v_member_id IN ARRAY p_member_ids
  LOOP
    IF v_member_id != v_my_id THEN
      INSERT INTO public.chat_members (chat_id, user_id, role)
      VALUES (v_chat_id, v_member_id, 'member')
      ON CONFLICT (chat_id, user_id) DO NOTHING;
    END IF;
  END LOOP;

  RETURN v_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- H. Get or create saved messages chat ("Избранное")
CREATE OR REPLACE FUNCTION public.get_or_create_saved_chat()
RETURNS UUID AS $$
DECLARE
  v_chat_id UUID;
  v_my_id UUID := auth.uid();
  v_key TEXT;
BEGIN
  IF v_my_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_key := 'saved_' || v_my_id::TEXT;

  SELECT id INTO v_chat_id FROM public.chats WHERE direct_key = v_key LIMIT 1;
  
  IF v_chat_id IS NOT NULL THEN
    INSERT INTO public.chat_members (chat_id, user_id, role)
    VALUES (v_chat_id, v_my_id, 'owner')
    ON CONFLICT (chat_id, user_id) DO NOTHING;

    RETURN v_chat_id;
  END IF;

  INSERT INTO public.chats (type, title, direct_key, created_by)
  VALUES ('saved', 'Избранное', v_key, v_my_id)
  RETURNING id INTO v_chat_id;

  INSERT INTO public.chat_members (chat_id, user_id, role)
  VALUES (v_chat_id, v_my_id, 'owner')
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  RETURN v_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_or_create_saved_chat() TO authenticated;

-- I. Toggle message reaction
CREATE OR REPLACE FUNCTION public.toggle_message_reaction(p_message_id UUID, p_emoji TEXT)
RETURNS VOID AS $$
DECLARE
  v_my_id UUID := auth.uid();
BEGIN
  IF v_my_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.message_reactions 
    WHERE message_id = p_message_id AND user_id = v_my_id AND emoji = p_emoji
  ) THEN
    DELETE FROM public.message_reactions
    WHERE message_id = p_message_id AND user_id = v_my_id AND emoji = p_emoji;
  ELSE
    INSERT INTO public.message_reactions (message_id, user_id, emoji)
    VALUES (p_message_id, v_my_id, p_emoji)
    ON CONFLICT (message_id, user_id, emoji) DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.toggle_message_reaction(UUID, TEXT) TO authenticated;

-- I. Toggle pin chat
CREATE OR REPLACE FUNCTION public.toggle_pin_chat(p_chat_id UUID, p_is_pinned BOOLEAN)
RETURNS VOID AS $$
BEGIN
  UPDATE public.chat_members
  SET is_pinned = p_is_pinned
  WHERE chat_id = p_chat_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- J. Pin / Unpin message in chat
CREATE OR REPLACE FUNCTION public.pin_message(p_chat_id UUID, p_message_id UUID DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.chats
  SET pinned_message_id = p_message_id
  WHERE id = p_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- K. Typing indicator & presence
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

-- L. Search messages inside a chat
CREATE OR REPLACE FUNCTION public.search_messages(p_chat_id UUID, p_query TEXT)
RETURNS SETOF public.messages AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM public.messages
  WHERE chat_id = p_chat_id
    AND content ILIKE '%' || p_query || '%'
  ORDER BY created_at DESC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- M. Membership checker for RLS
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

-- ==============================================================================
-- 11. ROW LEVEL SECURITY (RLS)
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- Profiles
DROP POLICY IF EXISTS "Profiles viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles viewable by authenticated users"
  ON public.profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Chat Members
DROP POLICY IF EXISTS "Chat members viewable by authenticated users" ON public.chat_members;
CREATE POLICY "Chat members viewable by authenticated users"
  ON public.chat_members FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert chat members" ON public.chat_members;
CREATE POLICY "Users can insert chat members"
  ON public.chat_members FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own member settings" ON public.chat_members;
CREATE POLICY "Users can update their own member settings"
  ON public.chat_members FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- Chats
DROP POLICY IF EXISTS "Users can view chats they belong to" ON public.chats;
CREATE POLICY "Users can view chats they belong to"
  ON public.chats FOR SELECT TO authenticated USING (public.is_chat_member(id, auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can create chats" ON public.chats;
CREATE POLICY "Authenticated users can create chats"
  ON public.chats FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Members can update chats" ON public.chats;
CREATE POLICY "Members can update chats"
  ON public.chats FOR UPDATE TO authenticated USING (public.is_chat_member(id, auth.uid()));

-- Messages
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
  USING (public.is_chat_member(chat_id, auth.uid()))
  WITH CHECK (
    (auth.uid() = sender_id) OR
    (public.is_chat_member(chat_id, auth.uid()))
  );

DROP POLICY IF EXISTS "Senders can delete their own messages" ON public.messages;
CREATE POLICY "Senders can delete their own messages"
  ON public.messages FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- Message Reactions
DROP POLICY IF EXISTS "Members can view reactions" ON public.message_reactions;
CREATE POLICY "Members can view reactions"
  ON public.message_reactions FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can manage their own reactions" ON public.message_reactions;
CREATE POLICY "Users can manage their own reactions"
  ON public.message_reactions FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Typing Indicators
DROP POLICY IF EXISTS "Members can view typing indicators" ON public.typing_indicators;
CREATE POLICY "Members can view typing indicators"
  ON public.typing_indicators FOR SELECT TO authenticated
  USING (public.is_chat_member(chat_id, auth.uid()));

DROP POLICY IF EXISTS "Users can set their own typing indicator" ON public.typing_indicators;
CREATE POLICY "Users can set their own typing indicator"
  ON public.typing_indicators FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Push tokens
DROP POLICY IF EXISTS "Users can manage their own push tokens" ON public.user_push_tokens;
CREATE POLICY "Users can manage their own push tokens"
  ON public.user_push_tokens FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ==============================================================================
-- 12. STORAGE BUCKETS (chat-media & avatars)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('chat-media', 'chat-media', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/wav', 'audio/m4a', 'video/mp4', 'application/pdf']),
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET 
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies
DROP POLICY IF EXISTS "Public view for chat media" ON storage.objects;
CREATE POLICY "Public view for chat media" ON storage.objects 
  FOR SELECT TO authenticated USING (bucket_id = 'chat-media');

DROP POLICY IF EXISTS "Auth upload for chat media" ON storage.objects;
CREATE POLICY "Auth upload for chat media" ON storage.objects 
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat-media');

DROP POLICY IF EXISTS "Auth delete for chat media" ON storage.objects;
CREATE POLICY "Auth delete for chat media" ON storage.objects 
  FOR DELETE TO authenticated USING (bucket_id = 'chat-media');

DROP POLICY IF EXISTS "Public view for avatars" ON storage.objects;
CREATE POLICY "Public view for avatars" ON storage.objects 
  FOR SELECT TO public USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Auth upload for avatars" ON storage.objects;
CREATE POLICY "Auth upload for avatars" ON storage.objects 
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');

-- 13. REALTIME PUBLICATION
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages, public.message_reactions, public.typing_indicators, public.chats, public.chat_members, public.profiles;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;
