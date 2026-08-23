import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Deploy this function on a daily schedule with RETENTION_CRON_SECRET. The
// database RPC anonymizes relational data and returns exact private object
// paths; Storage API removal is used because direct storage.objects DELETE is
// blocked by the storage extension's allow_delete_query trigger.
Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
  const secret = Deno.env.get('RETENTION_CRON_SECRET')
  if (!secret || req.headers.get('x-retention-secret') !== secret) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
  }
  const url = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !serviceKey) return new Response(JSON.stringify({ error: 'not_configured' }), { status: 503 })
  const admin = createClient(url, serviceKey)
  const { data: objects, error } = await admin.rpc('retention_cleanup')
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  const removed: Array<{ bucket: string; path: string }> = []
  for (const object of (objects ?? []) as Array<Record<string, unknown>>) {
    const queueId = Number(object.queue_id)
    const bucket = String(object.bucket_id ?? '')
    const path = String(object.object_path ?? '')
    if (!Number.isFinite(queueId) || !bucket || !path) continue
    const result = await admin.storage.from(bucket).remove([path])
    if (result.error) {
      await admin.rpc('retention_acknowledge', {
        p_queue_id: queueId,
        p_success: false,
        p_error: result.error.message,
      })
      continue
    }
    await admin.rpc('retention_acknowledge', {
      p_queue_id: queueId,
      p_success: true,
      p_error: null,
    })
    removed.push({ bucket, path })
  }
  return new Response(JSON.stringify({ removed: removed.length }), { headers: { 'content-type': 'application/json' } })
})
