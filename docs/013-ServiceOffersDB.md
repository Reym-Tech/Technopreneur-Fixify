Service Offers DB schema

This project expects a `service_offers` table in Supabase/Postgres with the following columns:

- id: text primary key (uuid or text)
- slug: text unique (e.g. 'pipe-leak-repair')
- service_name: text
- service_type: text (category, e.g. 'Plumbing')
- description: text
- image_path: text (optional) — path under assets or storage URL
- accent_color: bigint or text (store Color.value as int, or hex string e.g. '#FF007AFF')
- icon_codepoint: integer (optional) — Material icon codePoint
- icon_font_family: text (optional) — e.g. 'MaterialIcons'
- includes: text[] or jsonb (array of strings)
- price_range: text (e.g. '₱500 – ₱2,500')
- duration: text (e.g. '1–3 hours')
- tips: text (optional)
- created_at: timestamptz default now()

Example SQL seed (psql / Supabase SQL editor):

```sql
insert into service_offers (id, slug, service_name, service_type, description, image_path, accent_color, icon_codepoint, icon_font_family, includes, price_range, duration, tips)
values (
  uuid_generate_v4(),
  'pipe-leak-repair',
  'Pipe Leak Repair',
  'Plumbing',
  'A leaking pipe can waste hundreds of liters of water per day and cause serious structural damage to your home. Our verified plumbers will quickly locate the source, replace or seal the affected section, and test the repair to ensure a permanent fix.',
  'assets/images/pipeleakrepair.png',
  4278190335, -- example Color(0xFF007AFF).value
  0xea, -- replace with actual codePoint integer (example)
  'MaterialIcons',
  array['Inspection of visible and hidden pipes','Sealing or replacement of the leaking section','Pressure test after repair','Clean-up of the work area','30-day workmanship warranty'],
  '₱500 – ₱2,500',
  '1–3 hours',
  'Turn off your main water valve before the handyman arrives to prevent further damage.'
);
```

Notes:

- `accent_color` may be stored as integer (recommended) or hex string. The app tries both.
- `includes` should be stored as a Postgres text[] or jsonb array so the app can parse it into List<String>.
- If you prefer storing icons as names, adjust the app to map names to IconData.
