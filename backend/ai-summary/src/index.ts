interface Env {
  AI: Ai;
  BILL_SUMMARIES: KVNamespace;
}

const ALLOWED_ORIGINS = [
  "https://csearch.org",
  "http://localhost:3000",
  "http://192.168.1.153:8003",
];

const CACHE_TTL_SECONDS = 7 * 24 * 60 * 60; // 7 days

function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
  };

  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }

  return headers;
}

function jsonResponse(
  body: Record<string, unknown>,
  status: number,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(origin),
    },
  });
}

function buildPrompt(bill: Record<string, unknown>): string {
  const parts: string[] = [];

  const title = bill.shorttitle || bill.officialtitle;
  if (title) parts.push(`Title: ${title}`);
  if (bill.summary_text) parts.push(`Official Summary: ${bill.summary_text}`);
  if (bill.sponsor_name) {
    const sponsor = [bill.sponsor_name, bill.sponsor_party, bill.sponsor_state]
      .filter(Boolean)
      .join(", ");
    parts.push(`Sponsor: ${sponsor}`);
  }
  if (bill.policy_area) parts.push(`Policy Area: ${bill.policy_area}`);
  if (bill.bill_status) parts.push(`Current Status: ${bill.bill_status}`);

  if (Array.isArray(bill.actions) && bill.actions.length > 0) {
    const actionList = bill.actions
      .slice(0, 10)
      .map((a: Record<string, unknown>) => `- ${a.acted_at}: ${a.action_text}`)
      .join("\n");
    parts.push(`Recent Actions:\n${actionList}`);
  }

  if (Array.isArray(bill.votes) && bill.votes.length > 0) {
    const voteList = bill.votes
      .map(
        (v: Record<string, unknown>) =>
          `- ${v.chamber}: ${v.result} (${v.votedate})`,
      )
      .join("\n");
    parts.push(`Votes:\n${voteList}`);
  }

  if (Array.isArray(bill.cosponsors) && bill.cosponsors.length > 0) {
    const count = bill.cosponsors.length;
    const sample = bill.cosponsors
      .slice(0, 5)
      .map((c: Record<string, unknown>) => c.full_name || "Unknown")
      .join(", ");
    parts.push(
      `Cosponsors: ${count} total (including ${sample}${count > 5 ? ", and others" : ""})`,
    );
  }

  return parts.join("\n\n");
}

const SYSTEM_PROMPT = `You are a helpful assistant that explains U.S. congressional bills in plain English for a general audience. Given information about a bill, explain:
- What the bill does in simple terms
- Who sponsors it
- What has happened to it so far (key actions and votes)
- Whether it passed or is still pending

Keep your explanation to 2-3 short paragraphs. Do not use legal jargon. Write as if you are explaining to someone who does not follow politics closely.`;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get("Origin");

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(origin),
      });
    }

    if (request.method !== "GET") {
      return jsonResponse({ error: "Method not allowed" }, 405, origin);
    }

    // Parse the route: /summarize/:billtype/:congress/:billnumber
    const url = new URL(request.url);
    const match = url.pathname.match(
      /^\/summarize\/([a-z]+)\/(\d+)\/(\d+)\/?$/,
    );

    if (!match) {
      return jsonResponse(
        {
          error: "Not found. Use /summarize/:billtype/:congress/:billnumber",
        },
        404,
        origin,
      );
    }

    const [, billtype, congress, billnumber] = match;
    const cacheKey = `summary:${billtype}:${congress}:${billnumber}`;
    const billId = `${billtype}-${congress}-${billnumber}`;

    // 1. Check KV cache
    try {
      const cached = await env.BILL_SUMMARIES.get(cacheKey);
      if (cached) {
        return jsonResponse(
          { bill: billId, summary: cached, cached: true },
          200,
          origin,
        );
      }
    } catch (err) {
      // KV read failed — proceed without cache
      console.error("KV read error:", err);
    }

    // 2. Fetch bill data from upstream API
    let billData: Record<string, unknown>;
    try {
      const apiUrl = `https://api.csearch.org/bills/${billtype}/${congress}/${billnumber}`;
      const apiResponse = await fetch(apiUrl);

      if (!apiResponse.ok) {
        return jsonResponse(
          {
            error: `Failed to fetch bill data: ${apiResponse.status} ${apiResponse.statusText}`,
            bill: billId,
          },
          apiResponse.status === 404 ? 404 : 502,
          origin,
        );
      }

      billData = (await apiResponse.json()) as Record<string, unknown>;
    } catch (err) {
      return jsonResponse(
        { error: "Failed to fetch bill data from upstream API", bill: billId },
        502,
        origin,
      );
    }

    // 3. Build prompt and call Workers AI
    const userPrompt = buildPrompt(billData);
    let summary: string;

    try {
      const aiResponse = (await env.AI.run(
        "@cf/meta/llama-3.3-70b-instruct-fp8-fast",
        {
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            {
              role: "user",
              content: `Please explain this bill:\n\n${userPrompt}`,
            },
          ],
          max_tokens: 512,
          temperature: 0.3,
        },
      )) as { response?: string };

      if (!aiResponse.response) {
        return jsonResponse(
          { error: "AI model returned an empty response", bill: billId },
          502,
          origin,
        );
      }

      summary = aiResponse.response;
    } catch (err) {
      return jsonResponse(
        { error: "AI summarization failed", bill: billId },
        502,
        origin,
      );
    }

    // 4. Cache the result in KV (don't block the response on this)
    try {
      await env.BILL_SUMMARIES.put(cacheKey, summary, {
        expirationTtl: CACHE_TTL_SECONDS,
      });
    } catch (err) {
      console.error("KV write error:", err);
    }

    // 5. Return the summary
    return jsonResponse(
      { bill: billId, summary, cached: false },
      200,
      origin,
    );
  },
} satisfies ExportedHandler<Env>;
