// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// List every table that stores a userId FK
const TABLES_TO_CASCADE = [
  'wardrobe_items',
  'import_jobs',
  // 'add_more_here'
]

Deno.serve(async (req) => {
  try {
    // 1. Get the Bearer JWT from the Authorization header
    const authHeader = req.headers.get('authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response('Missing authorization header', { status: 401 })
    }
    
    const jwt = authHeader.replace('Bearer ', '').trim()
    
    // 2. Create admin client and verify the user
    const admin = createClient(supabaseUrl, serviceRoleKey)
    const { data: { user }, error } = await admin.auth.getUser(jwt)
    
    if (error || !user) {
      return new Response('Invalid token', { status: 401 })
    }
    
    const uid = user.id

    // 3. Delete child rows from all tables
    for (const table of TABLES_TO_CASCADE) {
      const { error: deleteError } = await admin.from(table).delete().eq('userId', uid)
      if (deleteError) {
        console.error(`Error deleting from ${table}:`, deleteError)
        // Continue with other tables even if one fails
      }
    }

    // 4. Delete the auth user itself
    const { error: userDeleteError } = await admin.auth.admin.deleteUser(uid)
    if (userDeleteError) {
      console.error('Error deleting user:', userDeleteError)
      return new Response('Failed to delete user', { status: 500 })
    }

    return new Response(JSON.stringify({ status: 'ok' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('delete-account error:', err)
    return new Response('Internal server error', { status: 500 })
  }
})