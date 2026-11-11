import type { Metadata } from 'next';
import localFont from 'next/font/local';
import './globals.css';

// Cairo is bundled in the project (app/fonts, same files as the app) so the build never has to download it.
const cairo = localFont({
  src: [
    { path: './fonts/Cairo-Regular.ttf', weight: '400', style: 'normal' },
    { path: './fonts/Cairo-Medium.ttf', weight: '500', style: 'normal' },
    { path: './fonts/Cairo-SemiBold.ttf', weight: '600', style: 'normal' },
    { path: './fonts/Cairo-Bold.ttf', weight: '700', style: 'normal' },
    { path: './fonts/Cairo-ExtraBold.ttf', weight: '800', style: 'normal' },
  ],
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL('https://dars.app'),
  title: 'Dars | درس',
  description: 'Private tutors online & in person — مدرسون خصوصيون أونلاين وحضورياً',
  icons: { icon: `${process.env.NEXT_PUBLIC_BASE_PATH || ''}/favicon.svg` },
};

/** Root shell. Language & direction are applied by app/[lang]/layout.tsx. */
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <body className={cairo.className}>{children}</body>
    </html>
  );
}
