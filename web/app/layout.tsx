import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Rewinded - Your travel memories, beautifully organized",
  description: "Organize your trips into beautiful visual stories. Share moments with friends and relive your adventures.",
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased bg-white">
        {children}
      </body>
    </html>
  );
}
