// ============================================================================
// Ligação ao Supabase — PREENCHE AQUI os dados do teu projeto.
// Project Settings > API, no painel do Supabase.
// ============================================================================
const SUPABASE_URL = "https://jixbsdhiingyivfczafe.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_0E7utZEXTFh3uMoOVK3pCQ_iBVAPSGJ";

// Carregado via <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
window.supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
