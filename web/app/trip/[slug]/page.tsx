import { Metadata } from 'next';
import { convex } from '@/lib/convex';

interface PageProps {
  params: Promise<{ slug: string }>;
}

interface TripPreview {
  trip: {
    tripId: string;
    title: string;
    startDate: number;
    endDate: number;
    shareSlug?: string;
    shareCode?: string;
    coverImageStorageId?: string;
  };
  moments: Array<{
    momentId: string;
    title: string;
    mediaCount: number;
    firstMediaStorageId?: string;
  }>;
  totalMoments: number;
}

async function getTripData(slug: string): Promise<TripPreview | null> {
  try {
    const data = await convex.query('trips:getPublicPreview' as any, {
      shareSlug: slug,
    });
    return data as TripPreview | null;
  } catch (error) {
    console.error('Error fetching trip:', error);
    return null;
  }
}

function formatDate(timestamp: number) {
  return new Date(timestamp).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  });
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const data = await getTripData(slug);

  if (!data) {
    return {
      title: 'Trip Not Found - Rewinded',
    };
  }

  return {
    title: `${data.trip.title} - Rewinded`,
    description: `Join me on my ${data.trip.title} trip! ${data.totalMoments} moments from ${formatDate(data.trip.startDate)} to ${formatDate(data.trip.endDate)}`,
    openGraph: {
      title: data.trip.title,
      description: `${data.totalMoments} moments • ${formatDate(data.trip.startDate)} - ${formatDate(data.trip.endDate)}`,
      type: 'website',
      url: `https://rewinded.app/trip/${slug}`,
    },
    twitter: {
      card: 'summary_large_image',
      title: data.trip.title,
      description: `${data.totalMoments} moments from this amazing trip`,
    },
  };
}

export default async function TripPreviewPage({ params }: PageProps) {
  const { slug } = await params;
  const data = await getTripData(slug);

  if (!data) {
    return (
      <div className="min-h-screen flex items-center justify-center px-6">
        <div className="max-w-md text-center">
          <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
            <svg className="w-10 h-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M12 12h.01M12 12h.01M12 12h.01M12 12h.01" />
            </svg>
          </div>
          <h1 className="text-2xl font-bold mb-3">Trip Not Found</h1>
          <p className="text-ios-gray mb-8">
            This trip link is invalid or has been disabled.
          </p>
          <a
            href="/"
            className="inline-block px-6 py-3 bg-ios-blue text-white rounded-ios font-semibold hover:bg-blue-600 transition-colors"
          >
            Go Home
          </a>
        </div>
      </div>
    );
  }

  const { trip, moments, totalMoments } = data;

  return (
    <div className="min-h-screen bg-ios-lightgray">
      {/* Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-6 py-6">
          <a href="/" className="inline-flex items-center text-ios-blue text-sm font-medium mb-4 hover:underline">
            <svg className="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Home
          </a>
        </div>
      </div>

      {/* Hero Section */}
      <div className="bg-white py-16">
        <div className="max-w-4xl mx-auto px-6">
          <div className="text-center mb-8">
            {/* Icon */}
            <div className="inline-flex items-center justify-center w-20 h-20 rounded-ios-lg bg-gradient-to-br from-ios-blue to-blue-600 mb-6">
              <svg className="w-11 h-11 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
              </svg>
            </div>

            {/* Trip Title */}
            <h1 className="text-4xl md:text-5xl font-bold mb-4 text-gray-900">
              {trip.title}
            </h1>

            {/* Trip Dates */}
            <p className="text-lg text-ios-gray mb-2">
              {formatDate(trip.startDate)} - {formatDate(trip.endDate)}
            </p>

            {/* Moments Count */}
            <p className="text-ios-gray">
              {totalMoments} {totalMoments === 1 ? 'moment' : 'moments'}
            </p>
          </div>

          {/* Trip Code */}
          <div className="max-w-md mx-auto mb-12">
            <div className="bg-ios-lightgray rounded-ios-lg p-6 text-center">
              <p className="text-xs text-ios-gray uppercase tracking-wide mb-2">Trip Code</p>
              <p className="text-3xl font-bold tracking-[0.2em] text-ios-blue">
                {trip.shareCode}
              </p>
              <p className="text-xs text-ios-gray mt-2">
                Use this code in the app to join
              </p>
            </div>
          </div>

          {/* CTA */}
          <div className="text-center">
            <a
              href={`rewinded://trip/${slug}`}
              className="inline-flex items-center justify-center px-8 py-4 text-lg font-semibold text-white bg-gray-900 rounded-ios hover:bg-gray-800 transition-colors mb-4"
            >
              <svg className="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
              Open in Rewinded
            </a>
            <p className="text-sm text-ios-gray">
              Download the app to view the full interactive trip
            </p>
          </div>
        </div>
      </div>

      {/* Moments Preview */}
      {moments.length > 0 && (
        <div className="py-16">
          <div className="max-w-4xl mx-auto px-6">
            <h2 className="text-2xl font-bold mb-8 text-gray-900">
              Moments Preview
            </h2>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
              {moments.map((moment) => (
                <div
                  key={moment.momentId}
                  className="bg-white rounded-ios-lg p-6 shadow-sm"
                >
                  <div className="w-full aspect-square bg-ios-lightgray rounded-ios mb-4 flex items-center justify-center">
                    <svg className="w-12 h-12 text-ios-gray" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <h3 className="font-semibold text-sm mb-1 line-clamp-2">
                    {moment.title}
                  </h3>
                  <p className="text-xs text-ios-gray">
                    {moment.mediaCount} {moment.mediaCount === 1 ? 'photo' : 'photos'}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Download Section */}
      <div className="bg-white py-16 border-t border-gray-200">
        <div className="max-w-2xl mx-auto px-6 text-center">
          <h2 className="text-3xl font-bold mb-4 text-gray-900">
            See the full story in the app
          </h2>
          <p className="text-lg text-ios-gray mb-8">
            Download Rewinded to explore this trip in an interactive canvas and create your own travel stories.
          </p>
          <a
            href="https://apps.apple.com/app/rewinded"
            className="inline-flex items-center justify-center px-8 py-4 text-lg font-semibold text-white bg-gray-900 rounded-ios hover:bg-gray-800 transition-colors"
          >
            <svg className="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            Download on the App Store
          </a>
        </div>
      </div>

      {/* Footer */}
      <footer className="py-12 bg-white border-t border-gray-200">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <p className="text-ios-gray text-sm">
            © 2025 Rewinded. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}
