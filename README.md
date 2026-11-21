# Circle — social platform

The `social-platform` branch replaces the Who Am I game with Circle, a phone-first social network.

## Features in this initial build
- SMS OTP sign-in through Supabase Auth
- Public profile details and opt-in phone-number discovery
- Posts, likes, comments and replies
- Follow relationships
- Private inbox with live updates (enable Supabase Realtime for the messages table)
- Message permissions: everyone, followers, or nobody
- Private phone numbers stored separately from public profiles

## Setup and deployment
1. Create a Supabase project and run `circle/database/schema.sql` in its SQL Editor.
2. Enable Phone authentication and configure an SMS provider.
3. Enable Realtime for the `messages` table.
4. Deploy the `social-platform` branch with the root `render.yaml` Blueprint.
5. Supply `SUPABASE_URL` and `SUPABASE_ANON_KEY` as Render environment secrets.
6. Add the deployed app URL to Supabase Authentication's allowed redirect/site URLs.

Never put the Supabase service-role key in browser code.

## Release limitations
This is a functional first foundation, not yet a public-production release. Media uploads, push notifications, message delivery/read receipts, abuse reporting/moderation, rate limiting, and an independent security review remain to be implemented. Keep public registration limited until these safeguards are added and tested.
