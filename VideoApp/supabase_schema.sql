-- ====================================================
-- VideoApp - Supabase Database Schema
-- Run this in your Supabase SQL Editor
-- ====================================================

-- PROFILES TABLE
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  bio text,
  avatar_url text,
  followers_count int default 0,
  following_count int default 0,
  created_at timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- VIDEOS TABLE
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  video_url text not null,
  thumbnail_url text,
  caption text default '',
  likes_count int default 0,
  comments_count int default 0,
  created_at timestamptz default now()
);

-- LIKES TABLE
create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  video_id uuid references public.videos(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(user_id, video_id)
);

-- COMMENTS TABLE
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  video_id uuid references public.videos(id) on delete cascade not null,
  content text not null,
  created_at timestamptz default now()
);

-- FOLLOWS TABLE
create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(follower_id, following_id)
);

-- ====================================================
-- FUNCTIONS for like/unlike
-- ====================================================

create or replace function increment_likes(video_id uuid)
returns void as $$
  update public.videos set likes_count = likes_count + 1 where id = video_id;
$$ language sql security definer;

create or replace function decrement_likes(video_id uuid)
returns void as $$
  update public.videos set likes_count = greatest(0, likes_count - 1) where id = video_id;
$$ language sql security definer;

create or replace function increment_comments(video_id uuid)
returns void as $$
  update public.videos set comments_count = comments_count + 1 where id = video_id;
$$ language sql security definer;

-- ====================================================
-- ROW LEVEL SECURITY (RLS)
-- ====================================================

alter table public.profiles enable row level security;
alter table public.videos enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;

create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);
create policy "videos_select" on public.videos for select using (true);
create policy "videos_insert" on public.videos for insert with check (auth.uid() = user_id);
create policy "videos_delete" on public.videos for delete using (auth.uid() = user_id);
create policy "likes_select" on public.likes for select using (true);
create policy "likes_insert" on public.likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.likes for delete using (auth.uid() = user_id);
create policy "comments_select" on public.comments for select using (true);
create policy "comments_insert" on public.comments for insert with check (auth.uid() = user_id);
create policy "comments_delete" on public.comments for delete using (auth.uid() = user_id);
create policy "follows_select" on public.follows for select using (true);
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

-- STORAGE BUCKETS
insert into storage.buckets (id, name, public) values ('videos', 'videos', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict do nothing;
create policy "videos_storage_select" on storage.objects for select using (bucket_id = 'videos');
create policy "videos_storage_insert" on storage.objects for insert with check (bucket_id = 'videos' and auth.role() = 'authenticated');
create policy "avatars_storage_select" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars_storage_insert" on storage.objects for insert with check (bucket_id = 'avatars' and auth.role() = 'authenticated');
