-- ==============================================================================
-- Migration: Edit & Delete messages with automatic chats sync and RLS policies
-- ==============================================================================

-- 1. Ensure REPLICA IDENTITY FULL on messages so Supabase Realtime sends full record on DELETE
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- 2. Trigger on message DELETE: update chats last_message_*
CREATE OR REPLACE FUNCTION public.handle_message_deleted()
RETURNS TRIGGER AS $$
DECLARE
  v_last_msg RECORD;
BEGIN
  -- If the deleted message was the last message of the chat
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

-- 3. Trigger on message UPDATE: update chats last_message_text if content changed
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

-- 4. RLS Policy for DELETE on messages
DROP POLICY IF EXISTS "Senders can delete their own messages" ON public.messages;
CREATE POLICY "Senders can delete their own messages"
  ON public.messages FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- 5. RLS Policy for UPDATE on messages
DROP POLICY IF EXISTS "Members can update messages" ON public.messages;
CREATE POLICY "Members can update messages"
  ON public.messages FOR UPDATE TO authenticated
  USING (public.is_chat_member(chat_id, auth.uid()))
  WITH CHECK (
    (auth.uid() = sender_id) OR
    (public.is_chat_member(chat_id, auth.uid()))
  );
