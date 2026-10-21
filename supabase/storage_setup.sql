-- ==============================================================================
-- SUPABASE STORAGE BUCKETS SETUP & SECURITY POLICIES
-- ==============================================================================

-- 1. Create 'chat-media' bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-media', 
  'chat-media', 
  true, 
  52428800, -- 50 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/mp4', 'audio/m4a', 'video/mp4', 'application/pdf', 'application/zip']
)
ON CONFLICT (id) DO UPDATE
SET 
  public = true,
  file_size_limit = 52428800;

-- 2. Create 'avatars' bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars', 
  'avatars', 
  true, 
  10485760, -- 10 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET 
  public = true,
  file_size_limit = 10485760;

-- 3. Storage Policies for 'chat-media'
DROP POLICY IF EXISTS "Public can view chat media" ON storage.objects;
CREATE POLICY "Public can view chat media"
  ON storage.objects FOR SELECT
  USING (bucket_id IN ('chat-media', 'avatars'));

DROP POLICY IF EXISTS "Authenticated users can upload chat media" ON storage.objects;
CREATE POLICY "Authenticated users can upload chat media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('chat-media', 'avatars'));

DROP POLICY IF EXISTS "Users can update their uploaded media" ON storage.objects;
CREATE POLICY "Users can update their uploaded media"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id IN ('chat-media', 'avatars') AND auth.uid() = owner);

DROP POLICY IF EXISTS "Users can delete their uploaded media" ON storage.objects;
CREATE POLICY "Users can delete their uploaded media"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('chat-media', 'avatars') AND auth.uid() = owner);
