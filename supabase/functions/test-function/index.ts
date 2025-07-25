import { serve } from 'https://deno.land/x/sift@0.6.0/mod.ts'

serve((_req) => {
  return new Response(JSON.stringify({ message: 'test function works!' }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
