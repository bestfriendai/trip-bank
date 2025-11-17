# Rewinded Web

Landing page and trip preview for rewinded.app

## Tech Stack

- **Next.js 15** - React framework with App Router
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **Convex** - Backend integration for trip previews

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## Environment Variables

Create a `.env.local` file:

```
NEXT_PUBLIC_CONVEX_URL=https://flippant-mongoose-94.convex.cloud
```

## Deployment

This site is designed to be deployed on Vercel:

1. Connect your GitHub repository to Vercel
2. Set environment variables in Vercel dashboard
3. Deploy

## Features

- **Landing Page** (`/`) - Marketing page for the app
- **Trip Preview** (`/trip/[slug]`) - Public preview of shared trips
  - Displays trip title, dates, and moments count
  - Shows trip code for manual app entry
  - Deep links to open in iOS app
  - Open Graph tags for rich link previews
- **Universal Links** - Seamless handoff from web to app

## Universal Links Setup

The `apple-app-site-association` file is served at `/.well-known/apple-app-site-association`.

**Note:** Update the `appID` in this file with your actual Team ID and Bundle ID before deploying.

## Design

Matches iOS app aesthetic:
- iOS Blue (#007AFF) primary color
- Clean, minimal design
- SF Pro Display typography (system font fallback)
- Rounded corners (12px standard, 16px large)
- Card-based layouts
