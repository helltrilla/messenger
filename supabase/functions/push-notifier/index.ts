// Supabase Edge Function: Push Notifier (Firebase Cloud Messaging)
// Triggered via Database Webhook on INSERT into public.messages

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") ?? "";

interface WebhookPayload {
  type: "INSERT";
  table: "messages";
  record: {
    id: string;
    chat_id: string;
    sender_id: string;
    content: string | null;
    type: string;
    created_at: string;
  };
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  try {
    const payload: WebhookPayload = await req.json();
    const { record } = payload;

    if (!record || !record.chat_id || !record.sender_id) {
      return new Response(JSON.stringify({ status: "skipped", reason: "Invalid record" }), { status: 200 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Get sender info
    const { data: sender } = await supabase
      .from("profiles")
      .select("display_name, username")
      .eq("id", record.sender_id)
      .single();

    const senderName = sender?.display_name || sender?.username || "Новое сообщение";

    // 2. Get recipients (chat members except sender)
    const { data: recipients } = await supabase
      .from("chat_members")
      .select("user_id, is_muted")
      .eq("chat_id", record.chat_id)
      .neq("user_id", record.sender_id);

    if (!recipients || recipients.length === 0) {
      return new Response(JSON.stringify({ status: "ok", sent: 0 }), { status: 200 });
    }

    // Filter out muted members
    const activeRecipientIds = recipients
      .filter((r) => !r.is_muted)
      .map((r) => r.user_id);

    if (activeRecipientIds.length === 0) {
      return new Response(JSON.stringify({ status: "ok", sent: 0, reason: "Muted" }), { status: 200 });
    }

    // 3. Get device push tokens for active recipients
    const { data: tokens } = await supabase
      .from("user_push_tokens")
      .select("token")
      .in("user_id", activeRecipientIds);

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ status: "ok", sent: 0, reason: "No tokens" }), { status: 200 });
    }

    const bodyPreview = record.type === "image"
      ? "📷 Фотография"
      : record.type === "voice"
      ? "🎤 Голосовое сообщение"
      : record.type === "file"
      ? "📎 Файл"
      : (record.content || "Новое сообщение");

    // 4. Send FCM pushes
    if (FCM_SERVER_KEY) {
      for (const t of tokens) {
        await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `key=${FCM_SERVER_KEY}`,
          },
          body: JSON.stringify({
            to: t.token,
            notification: {
              title: senderName,
              body: bodyPreview,
              sound: "default",
            },
            data: {
              chat_id: record.chat_id,
              message_id: record.id,
              sender_id: record.sender_id,
            },
            priority: "high",
          }),
        }).catch((err) => console.error("FCM send error:", err));
      }
    }

    return new Response(JSON.stringify({ status: "ok", sent: tokens.length }), { status: 200 });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Push notifier error:", message);
    return new Response(JSON.stringify({ error: message }), { status: 500 });
  }
});
