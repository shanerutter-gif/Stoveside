# Stoveside 🍳

**Real food, from the kitchen next door.**

MEHKO permit wizard + digital storefront + local marketplace for California home cooks. Built on AB 626.

## Structure

```
public/
  index.html   → SEO landing page (/)
  app.html     → The app (/app) — wizard, marketplace, operator dashboard
  config.js    → Supabase URL + publishable key
vercel.json    → Clean URLs, /app routing
```

## Deploy to Vercel (5 min)

1. Push to GitHub
2. Import at vercel.com/new — Framework: **Other**, Output directory: `public`
3. In [Supabase dashboard](https://supabase.com/dashboard/project/ijubcwmsgzejnicvittm) → Auth → URL Configuration, add your Vercel domain as an allowed redirect (e.g. `https://stoveside.vercel.app/**`)

Magic-link sign-in works immediately after step 3.

## Supabase project (provisioned)

- **ID:** `ijubcwmsgzejnicvittm`
- **URL:** `https://ijubcwmsgzejnicvittm.supabase.co`
- **Region:** us-west-1, Free tier
- **Dashboard:** https://supabase.com/dashboard/project/ijubcwmsgzejnicvittm

### Tables (all RLS-enabled)
- `profiles` — auto-created on signup via trigger
- `permit_applications` — wizard drafts
- `kitchens` — auto-created on permit approval via trigger
- `menu_items`, `availability`, `orders`, `order_items`
- `waitlist` — landing page email captures

### Edge function
- `waitlist-signup` — public, accepts `{ email, county, role, source, utm_* }` and upserts to waitlist table

### Seeded demo data
6 demo kitchens (SD), 17 menu items, 12 availability windows — all `is_demo = true`

## What works right now

**Consumer:** Browse kitchens → view menu → add to cart → magic-link sign-in → place order → order history loads from DB.

**Operator:** Sign in → dashboard auto-loads if you own a kitchen → see real orders, update statuses, add/remove menu items.

**Permit Wizard:** 6-step flow, auto-saves drafts to Supabase, final submit flips status to 'submitted'. Approval (manual for now) auto-creates kitchen row.

**Landing:** `/` is SEO-optimized (meta + OG + JSON-LD), collects email via edge function → redirects to `/app?email=...&src=landing`.

## Next build session — handoff

Shipped in v0.4:
- [x] County pages: `/permit/san-diego`, `/permit/los-angeles`, `/permit/riverside`, `/permit/alameda`, `/permit/santa-clara` (SEO-targeted, JSON-LD, fees/timeline/requirements/process, CTA → `/app?county=<slug>`)
- [x] Real PDF packet generation via pdf-lib (4-page packet: cover, cover letter, SOP, menu + schedule + signature)
- [x] URL param prefill on `/app`: `?email=`, `?county=`, `?name=`, `?phone=`, `?src=` — routes into wizard when `county` is present
- [x] Availability scheduling UI — operator Hours tab now reads/writes `availability` rows in Supabase

Still needed:
- [ ] Stripe Connect for real payments
- [ ] Photo uploads to Supabase Storage
- [ ] Email/SMS order notifications

## Run locally

```bash
npm run dev
# Or just open public/index.html in a browser
```

## Design

Fraunces (serif display) + DM Sans (body) + DM Mono (labels). Coral #FF6B4A on cream #F5EFE6. Editorial magazine feel.
