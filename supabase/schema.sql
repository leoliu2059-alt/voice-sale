create extension if not exists "pgcrypto";

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  industry text not null,
  value_statement text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.calls (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  title text not null,
  industry text not null,
  call_goal text not null,
  audio_path text,
  duration_seconds integer,
  status text not null default 'created',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calls_status_check check (status in ('created', 'uploaded', 'transcribing', 'analyzing', 'completed', 'failed'))
);

create table if not exists public.transcript_segments (
  id uuid primary key default gen_random_uuid(),
  call_id uuid not null references public.calls(id) on delete cascade,
  start_ms integer not null,
  end_ms integer not null,
  speaker text not null,
  text text not null,
  confidence numeric,
  created_at timestamptz not null default now()
);

create table if not exists public.review_results (
  id uuid primary key default gen_random_uuid(),
  call_id uuid not null references public.calls(id) on delete cascade,
  persona jsonb not null,
  decisive_misses jsonb not null,
  signals jsonb not null,
  next_call_talktrack jsonb not null,
  full_result jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.evidence_clips (
  id uuid primary key default gen_random_uuid(),
  call_id uuid not null references public.calls(id) on delete cascade,
  review_result_id uuid references public.review_results(id) on delete cascade,
  start_ms integer not null,
  end_ms integer not null,
  quote text not null,
  label text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.analysis_jobs (
  id uuid primary key default gen_random_uuid(),
  call_id uuid not null references public.calls(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  job_type text not null,
  status text not null default 'queued',
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint analysis_jobs_type_check check (job_type in ('transcription', 'review_analysis')),
  constraint analysis_jobs_status_check check (status in ('queued', 'running', 'completed', 'failed'))
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'call-audio',
  'call-audio',
  false,
  524288000,
  array[
    'audio/aac',
    'audio/aiff',
    'audio/flac',
    'audio/mp3',
    'audio/mp4',
    'audio/mpeg',
    'audio/wave',
    'audio/webm',
    'audio/wav',
    'audio/x-aac',
    'audio/x-aiff',
    'audio/x-caf',
    'audio/x-flac',
    'audio/x-m4a',
    'audio/x-wav',
    'video/mp4',
    'video/quicktime'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.products enable row level security;
alter table public.calls enable row level security;
alter table public.transcript_segments enable row level security;
alter table public.review_results enable row level security;
alter table public.evidence_clips enable row level security;
alter table public.analysis_jobs enable row level security;

drop policy if exists "users manage own products" on public.products;
drop policy if exists "users manage own calls" on public.calls;
drop policy if exists "users read own transcript segments" on public.transcript_segments;
drop policy if exists "users read own review results" on public.review_results;
drop policy if exists "users read own evidence clips" on public.evidence_clips;
drop policy if exists "users read own analysis jobs" on public.analysis_jobs;
drop policy if exists "users read own call audio" on storage.objects;
drop policy if exists "users upload own call audio" on storage.objects;
drop policy if exists "users update own call audio" on storage.objects;
drop policy if exists "users delete own call audio" on storage.objects;

create policy "users manage own products" on public.products
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "users manage own calls" on public.calls
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "users read own transcript segments" on public.transcript_segments
  for select using (
    exists (
      select 1 from public.calls
      where calls.id = transcript_segments.call_id
      and calls.user_id = (select auth.uid())
    )
  );

create policy "users read own review results" on public.review_results
  for select using (
    exists (
      select 1 from public.calls
      where calls.id = review_results.call_id
      and calls.user_id = (select auth.uid())
    )
  );

create policy "users read own evidence clips" on public.evidence_clips
  for select using (
    exists (
      select 1 from public.calls
      where calls.id = evidence_clips.call_id
      and calls.user_id = (select auth.uid())
    )
  );

create policy "users read own analysis jobs" on public.analysis_jobs
  for select using ((select auth.uid()) = user_id);

create policy "users read own call audio" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'call-audio'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "users upload own call audio" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'call-audio'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "users update own call audio" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'call-audio'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'call-audio'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "users delete own call audio" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'call-audio'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create index if not exists products_user_id_idx on public.products(user_id);
create index if not exists calls_user_id_created_at_idx on public.calls(user_id, created_at desc);
create index if not exists transcript_segments_call_id_start_ms_idx on public.transcript_segments(call_id, start_ms);
create index if not exists review_results_call_id_idx on public.review_results(call_id);
create index if not exists evidence_clips_call_id_start_ms_idx on public.evidence_clips(call_id, start_ms);
create index if not exists analysis_jobs_call_id_idx on public.analysis_jobs(call_id);
