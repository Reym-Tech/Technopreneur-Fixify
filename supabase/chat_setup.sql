-- Chat + Push Tokens setup for Fixify (Supabase)
-- Run in Supabase SQL editor (public schema).
--
-- Creates:
--   - chat_threads (1 per booking)
--   - chat_messages (messages per thread)
--   - user_push_tokens (FCM tokens per user/device)
--
-- Security:
--   RLS enabled with policies so only the booking customer and the assigned
--   professional (via professionals.user_id) can access chat data.

begin;

-- ─────────────────────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────────────────────

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  last_message_preview text
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_thread_created_at_idx
  on public.chat_messages(thread_id, created_at desc);

create index if not exists chat_messages_booking_created_at_idx
  on public.chat_messages(booking_id, created_at desc);

create index if not exists chat_messages_sender_created_at_idx
  on public.chat_messages(sender_id, created_at desc);

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  platform text not null check (platform in ('android','ios','web')),
  token text not null,
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists user_push_tokens_user_id_idx
  on public.user_push_tokens(user_id);

-- ─────────────────────────────────────────────────────────────
-- Basic integrity helpers
-- ─────────────────────────────────────────────────────────────

-- Ensure chat_messages.booking_id matches the thread's booking_id
create or replace function public._chat_message_booking_guard()
returns trigger
language plpgsql
as $$
declare
  thread_booking uuid;
begin
  select booking_id into thread_booking
  from public.chat_threads
  where id = new.thread_id;

  if thread_booking is null then
    raise exception 'chat thread not found';
  end if;

  if new.booking_id <> thread_booking then
    raise exception 'booking_id must match thread booking_id';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_chat_message_booking_guard on public.chat_messages;
create trigger trg_chat_message_booking_guard
before insert or update on public.chat_messages
for each row
execute function public._chat_message_booking_guard();

-- Update thread last_message fields on new message
create or replace function public._chat_thread_last_message_update()
returns trigger
language plpgsql
as $$
begin
  update public.chat_threads
  set
    last_message_at = new.created_at,
    last_message_preview = left(new.body, 140)
  where id = new.thread_id;
  return new;
end;
$$;

drop trigger if exists trg_chat_thread_last_message_update on public.chat_messages;
create trigger trg_chat_thread_last_message_update
after insert on public.chat_messages
for each row
execute function public._chat_thread_last_message_update();

-- ─────────────────────────────────────────────────────────────
-- Realtime publication
-- ─────────────────────────────────────────────────────────────

-- Supabase uses the `supabase_realtime` publication for Realtime.
-- This is safe to run multiple times.
alter publication supabase_realtime add table public.chat_messages;

-- ─────────────────────────────────────────────────────────────
-- Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.user_push_tokens enable row level security;

-- Helper predicate (inline via EXISTS) to determine if auth.uid() is a
-- participant in the booking's chat (customer or assigned professional user).

-- chat_threads: select
drop policy if exists "chat_threads_select_participants" on public.chat_threads;
create policy "chat_threads_select_participants"
on public.chat_threads
for select
using (
  exists (
    select 1
    from public.bookings b
    left join public.professionals p on p.id = b.professional_id
    where b.id = chat_threads.booking_id
      and (
        auth.uid() = b.customer_id
        or auth.uid() = p.user_id
      )
  )
);

-- chat_threads: insert (allow participants to create the thread for a booking)
drop policy if exists "chat_threads_insert_participants" on public.chat_threads;
create policy "chat_threads_insert_participants"
on public.chat_threads
for insert
with check (
  exists (
    select 1
    from public.bookings b
    left join public.professionals p on p.id = b.professional_id
    where b.id = chat_threads.booking_id
      and (
        auth.uid() = b.customer_id
        or auth.uid() = p.user_id
      )
  )
);

-- chat_threads: update (participants only)
drop policy if exists "chat_threads_update_participants" on public.chat_threads;
create policy "chat_threads_update_participants"
on public.chat_threads
for update
using (
  exists (
    select 1
    from public.bookings b
    left join public.professionals p on p.id = b.professional_id
    where b.id = chat_threads.booking_id
      and (
        auth.uid() = b.customer_id
        or auth.uid() = p.user_id
      )
  )
)
with check (
  exists (
    select 1
    from public.bookings b
    left join public.professionals p on p.id = b.professional_id
    where b.id = chat_threads.booking_id
      and (
        auth.uid() = b.customer_id
        or auth.uid() = p.user_id
      )
  )
);

-- chat_messages: select (participants only; uses booking_id)
drop policy if exists "chat_messages_select_participants" on public.chat_messages;
create policy "chat_messages_select_participants"
on public.chat_messages
for select
using (
  exists (
    select 1
    from public.bookings b
    left join public.professionals p on p.id = b.professional_id
    where b.id = chat_messages.booking_id
      and (
        auth.uid() = b.customer_id
        or auth.uid() = p.user_id
      )
  )
);

-- chat_messages: insert (participants only; sender must be auth.uid())
drop policy if exists "chat_messages_insert_participants" on public.chat_messages;
create policy "chat_messages_insert_participants"
on public.chat_messages
for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.bookings b
    left join public.professionals p on p.id = b.professional_id
    where b.id = chat_messages.booking_id
      and (
        auth.uid() = b.customer_id
        or auth.uid() = p.user_id
      )
  )
);

-- chat_messages: update/delete disabled by default (immutable messages)
-- (No policies created for update/delete)

-- user_push_tokens: a user can manage their own tokens only
drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
create policy "user_push_tokens_select_own"
on public.user_push_tokens
for select
using (auth.uid() = user_id);

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
on public.user_push_tokens
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
on public.user_push_tokens
for delete
using (auth.uid() = user_id);

commit;

