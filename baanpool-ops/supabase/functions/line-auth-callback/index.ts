// Supabase Edge Function: line-auth-callback
// Deploy: supabase functions deploy line-auth-callback
//
// This function exchanges a LINE authorization code for tokens,
// fetches the user profile, and creates/signs in a Supabase user.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LINE_TOKEN_URL = "https://api.line.me/oauth2/v2.1/token";
const LINE_PROFILE_URL = "https://api.line.me/v2/profile";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LINE_CHANNEL_ID = Deno.env.get("LINE_CHANNEL_ID")!;
const LINE_CHANNEL_SECRET = Deno.env.get("LINE_CHANNEL_SECRET")!;

serve(async (req) => {
  try {
    const { code, redirect_uri } = await req.json();

    if (!code) {
      return new Response(JSON.stringify({ error: "Missing authorization code" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 1. Exchange code for LINE access token
    const tokenRes = await fetch(LINE_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri,
        client_id: LINE_CHANNEL_ID,
        client_secret: LINE_CHANNEL_SECRET,
      }),
    });

    const tokenData = await tokenRes.json();

    if (tokenData.error) {
      return new Response(JSON.stringify({ error: tokenData.error_description }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Get LINE user profile
    const profileRes = await fetch(LINE_PROFILE_URL, {
      headers: { Authorization: `Bearer ${tokenData.access_token}` },
    });
    const profile = await profileRes.json();

    // 3. Create or sign in Supabase user
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Use LINE userId as a unique identifier
    const email = `line_${profile.userId}@baanpool-ops.app`;
    const password = `line_${profile.userId}_${LINE_CHANNEL_SECRET.substring(0, 8)}`;

    // Try to sign in first
    let { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    // If user doesn't exist, create one
    if (signInError) {
      const { data: signUpData, error: signUpError } = await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: profile.displayName,
          avatar_url: profile.pictureUrl,
          line_user_id: profile.userId,
          provider: "line",
        },
      });

      if (signUpError) {
        return new Response(JSON.stringify({ error: signUpError.message }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Sign in after creating
      const result = await supabase.auth.signInWithPassword({ email, password });
      signInData = result.data;

      // Also insert into users table
      await supabase.from("users").upsert({
        id: signUpData.user?.id,
        email,
        full_name: profile.displayName,
        role: "technician",
      });
    }

    return new Response(
      JSON.stringify({
        access_token: signInData?.session?.access_token,
        refresh_token: signInData?.session?.refresh_token,
        user: signInData?.user,
        line_profile: {
          displayName: profile.displayName,
          pictureUrl: profile.pictureUrl,
          userId: profile.userId,
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
