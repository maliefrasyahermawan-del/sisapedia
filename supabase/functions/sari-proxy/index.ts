import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type Operation = 'extract' | 'chat' | 'insight'
const extraction = (value: Record<string, unknown>) =>
  ['organik', 'anorganik'].includes(String(value.kategori)) &&
  typeof value.subtipe === 'string' && String(value.subtipe).trim().length > 0 &&
  typeof value.berat_kg === 'number' && Number.isFinite(value.berat_kg) && value.berat_kg > 0 &&
  typeof value.confidence === 'number' && Number.isFinite(value.confidence) && value.confidence >= 0 && value.confidence <= 1 &&
  (value.perlu_klarifikasi === undefined || typeof value.perlu_klarifikasi === 'boolean')

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
  const authorization = req.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')
  if (!supabaseUrl || !publishableKey) return new Response(JSON.stringify({ error: 'gateway_not_configured' }), { status: 503 })
  const caller = createClient(supabaseUrl, publishableKey, { global: { headers: { Authorization: authorization } } })
  const { data: userData, error: userError } = await caller.auth.getUser()
  if (userError || !userData.user) return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
  const { data: profile, error: profileError } = await caller
    .from('profiles').select('primary_role').eq('id', userData.user.id).maybeSingle()
  if (profileError || profile?.primary_role !== 'sumber') return new Response(JSON.stringify({ error: 'sumber_required' }), { status: 403 })
  const { data: allowed, error: limitError } = await caller.rpc('consume_sari_rate_limit', { p_user_id: userData.user.id, p_max_requests: 20 })
  if (limitError || allowed !== true) return new Response(JSON.stringify({ error: 'rate_limited' }), { status: 429 })
  const body = await req.json().catch(() => null)
  const operation = body?.operation as Operation
  if (!body || !['extract', 'chat', 'insight'].includes(operation) || typeof body.prompt !== 'string' || body.prompt.length > 2000) {
    return new Response(JSON.stringify({ error: 'invalid_request' }), { status: 400 })
  }
  const system = operation === 'extract'
    ? 'Return JSON only with kategori (organik/anorganik), subtipe, positive berat_kg, confidence 0..1, perlu_klarifikasi boolean.'
    : operation === 'chat'
      ? 'Answer the Indonesian recycling question briefly as JSON {text:string}. Do not invent personal data.'
      : 'Summarize the supplied aggregate recycling data briefly as JSON {text:string}; label estimates.'
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 15000)
  let upstream: Response
  try {
    upstream = await fetch(Deno.env.get('ROUTER_BASE_URL') ?? 'https://api.9router.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${Deno.env.get('NINJA_API_KEY') ?? ''}` },
      body: JSON.stringify({ model: Deno.env.get('ROUTER_MODEL') ?? 'gpt-4o-mini', temperature: 0, response_format: { type: 'json_object' }, messages: [{ role: 'system', content: system }, { role: 'user', content: body.prompt }] }),
      signal: controller.signal,
    })
  } catch (_) {
    return new Response(JSON.stringify({ error: 'upstream_timeout' }), { status: 504 })
  } finally {
    clearTimeout(timeout)
  }
  if (!upstream.ok) return new Response(JSON.stringify({ error: 'upstream_unavailable' }), { status: 502 })
  const data = await upstream.json().catch(() => null)
  const content = data?.choices?.[0]?.message?.content
  let parsed: Record<string, unknown>
  try { parsed = JSON.parse(content) } catch (_) { return new Response(JSON.stringify({ error: 'invalid_model_json' }), { status: 502 }) }
  if (operation === 'extract' && !extraction(parsed)) return new Response(JSON.stringify({ error: 'invalid_schema' }), { status: 502 })
  if ((operation === 'chat' || operation === 'insight') && typeof parsed.text !== 'string') return new Response(JSON.stringify({ error: 'invalid_schema' }), { status: 502 })
  return new Response(JSON.stringify(parsed), { headers: { 'Content-Type': 'application/json' } })
})
