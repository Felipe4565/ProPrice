// supabase/functions/check-market/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

const PRICE_VARIATION_THRESHOLD = 0.03; // 3% -> considéré comme "significatif"

// --- Authentification Google (OAuth2 via compte de service, requis par FCM HTTP v1) ---
async function getAccessToken(serviceAccountJson: string): Promise<{ token: string; projectId: string }> {
  const serviceAccount = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const base64url = (input: Uint8Array | string) => {
    const bytes = typeof input === "string" ? encoder.encode(input) : input;
    let str = btoa(String.fromCharCode(...bytes));
    return str.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  };

  const headerB64 = base64url(JSON.stringify(header));
  const payloadB64 = base64url(JSON.stringify(payload));
  const unsigned = `${headerB64}.${payloadB64}`;

  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(unsigned),
  );

  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Échec obtention access_token Google: ${JSON.stringify(data)}`);
  }

  return { token: data.access_token, projectId: serviceAccount.project_id };
}

async function sendPush(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
        },
      }),
    },
  );

  if (!res.ok) {
    const err = await res.text();
    console.error(`Échec envoi push (token ${token.slice(0, 12)}...): ${err}`);
  }
}

Deno.serve(async (_req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("Secret FIREBASE_SERVICE_ACCOUNT manquant");
    }
    const { token: accessToken, projectId } = await getAccessToken(serviceAccountJson);

    // 1. Récupérer tous les prix actuels
    const { data: prices, error: pricesError } = await supabaseAdmin
      .from("commodity_prices")
      .select("*");
    if (pricesError) throw pricesError;

    type Notif = { userId: string; title: string; body: string; data: Record<string, string> };
    const notifications: Notif[] = [];

    for (const p of prices ?? []) {
      if (p.previous_price === null) continue;
      const prev = Number(p.previous_price);
      const curr = Number(p.current_price);
      if (prev === curr) continue; // rien n'a changé depuis le dernier passage

      // --- a) Alertes de seuil déclenchées ---
      const { data: alerts } = await supabaseAdmin
        .from("alerts")
        .select("*")
        .eq("commodity", p.commodity)
        .eq("status", "active");

      for (const alert of alerts ?? []) {
        const threshold = Number(alert.price);
        const crossedUp = prev < threshold && curr >= threshold;
        const crossedDown = prev > threshold && curr <= threshold;

        if (crossedUp || crossedDown) {
          notifications.push({
            userId: alert.user_id,
            title: `Alerte ${p.commodity.toUpperCase()}`,
            body: `Le prix a atteint ${curr} $ (seuil : ${threshold} $)`,
            data: { type: "alert", commodity: p.commodity },
          });

          await supabaseAdmin
            .from("alerts")
            .update({ status: "triggered" })
            .eq("id", alert.id);
        }
      }

      // --- b) Variation significative du prix ---
      const pctChange = (curr - prev) / prev;
      if (Math.abs(pctChange) >= PRICE_VARIATION_THRESHOLD) {
        const { data: favUsers } = await supabaseAdmin
          .from("favorites")
          .select("user_id")
          .eq("grain_name", p.commodity);

        const direction = pctChange > 0 ? "hausse" : "chute";
        const pctLabel = `${(pctChange * 100).toFixed(1)}%`;

        for (const fav of favUsers ?? []) {
          notifications.push({
            userId: fav.user_id,
            title: `${p.commodity.toUpperCase()} en ${direction}`,
            body: `Variation de ${pctLabel} (nouveau prix : ${curr} $)`,
            data: { type: "price_variation", commodity: p.commodity },
          });
        }
      }
    }

    // 2. Envoyer les notifications collectées
    const userIds = [...new Set(notifications.map((n) => n.userId))];
    let tokenRows: { user_id: string; token: string }[] = [];
    if (userIds.length > 0) {
      const { data } = await supabaseAdmin
        .from("device_tokens")
        .select("user_id, token")
        .in("user_id", userIds);
      tokenRows = data ?? [];
    }

    const tokensByUser = new Map<string, string[]>();
    for (const row of tokenRows) {
      const list = tokensByUser.get(row.user_id) ?? [];
      list.push(row.token);
      tokensByUser.set(row.user_id, list);
    }

    for (const n of notifications) {
      const tokens = tokensByUser.get(n.userId) ?? [];
      for (const token of tokens) {
        await sendPush(accessToken, projectId, token, n.title, n.body, n.data);
      }
    }

    // 3. Réinitialiser la base de comparaison pour le prochain passage
    for (const p of prices ?? []) {
      if (p.previous_price !== p.current_price) {
        await supabaseAdmin
          .from("commodity_prices")
          .update({ previous_price: p.current_price })
          .eq("commodity", p.commodity);
      }
    }

    return new Response(
      JSON.stringify({ notificationsSent: notifications.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});