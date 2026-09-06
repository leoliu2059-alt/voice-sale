-- Backend-only analysis lifecycle. Client writes remain intentionally restricted.

alter table public.calls
  add column if not exists error_message text,
  add column if not exists processing_version integer not null default 1,
  add column if not exists audio_mime_type text,
  add column if not exists audio_size_bytes bigint;

alter table public.calls
  drop constraint if exists calls_audio_size_bytes_check;

alter table public.calls
  add constraint calls_audio_size_bytes_check
  check (audio_size_bytes is null or audio_size_bytes between 1 and 26214400);

alter table public.analysis_jobs
  add column if not exists progress smallint not null default 0,
  add column if not exists provider text,
  add column if not exists model text,
  add column if not exists started_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists attempt_count integer not null default 0;

alter table public.analysis_jobs
  drop constraint if exists analysis_jobs_progress_check;

alter table public.analysis_jobs
  add constraint analysis_jobs_progress_check check (progress between 0 and 100);

create index if not exists analysis_jobs_call_type_created_idx
  on public.analysis_jobs (call_id, job_type, created_at desc);

-- A mobile client may create a call and upload its object, but the processing
-- status and object path are set only by the authenticated Edge Function.
drop policy if exists "users manage own calls" on public.calls;
drop policy if exists "users read own calls" on public.calls;
drop policy if exists "users create own calls" on public.calls;

create policy "users read own calls" on public.calls
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "users create own calls" on public.calls
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and status = 'created'
    and audio_path is null
    and error_message is null
  );

-- Audio is immutable once uploaded. It is inspected and attached to the call
-- only after the Edge Function verifies both ownership and path.
drop policy if exists "users update own call audio" on storage.objects;
drop policy if exists "users delete own call audio" on storage.objects;

update storage.buckets
  set file_size_limit = 26214400
  where id = 'call-audio';
