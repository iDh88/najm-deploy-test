export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GLM_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'GLM_API_KEY is not configured' });
  }

  const body = req.body || {};
  const message = body.message || '';

  const response = await fetch('https://api.z.ai/api/paas/v4/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: process.env.GLM_MODEL || 'glm-4.5',
      messages: [
        { role: 'system', content: 'You are Najm, an Arabic/English assistant for a crew intelligence platform. Be concise, helpful, and clear.' },
        { role: 'user', content: message }
      ],
      max_tokens: 700,
      temperature: 0.3
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    return res.status(response.status).json(data);
  }

  return res.status(200).json({
    text: data.choices?.[0]?.message?.content || '',
    intent_type: 'general',
    rich_content: { line_card: null, legality_card: null, filter_query: null, filter_result: null },
    response_time_ms: 0,
    tokens_used: data.usage?.total_tokens || 0
  });
}
