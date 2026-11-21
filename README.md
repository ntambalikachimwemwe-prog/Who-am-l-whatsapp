# Social Hub

A mobile-friendly social networking starter built with Node.js, Express and Socket.IO.

## Features
- Phone number + PIN account registration and sign-in
- User profiles and phone-number member lookup
- Community feed with posts, likes, comments and replies
- Private one-to-one inbox and live message notifications
- Responsive layout for mobile and desktop

## Run locally
```bash
npm install
npm start
```
Open http://localhost:10000.

## Important deployment note
This starter currently keeps accounts, posts and messages in server memory. Data is lost when the server restarts or redeploys, and phone numbers are not verified by SMS. Before public production use, connect persistent PostgreSQL storage, add verified phone authentication, rate limiting, moderation/reporting and privacy controls. Do not use real sensitive conversations until those protections are implemented.
