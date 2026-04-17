/* Stoveside — Supabase config
 * The publishable key is safe to expose publicly. Row Level Security is what protects your data.
 * If you rotate or regenerate these, update them here.
 */
window.STOVESIDE_CONFIG = {
  supabaseUrl: 'https://ijubcwmsgzejnicvittm.supabase.co',
  supabaseKey: 'sb_publishable_qyYoQAEce4pUF-pIPZyoNg_ouplLmq0',
  // Set to false to disable auth requirement and let anyone order as guest (MVP-friendly)
  requireAuthForOrders: true,
  // Toggle to show demo badges on seeded kitchens
  showDemoBadges: false,
};
