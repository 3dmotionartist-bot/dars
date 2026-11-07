/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  basePath: process.env.BASE_PATH || '',  // set by the GitHub build for github.io/<repo>/          // static site → /out (host anywhere: Netlify, Vercel, Firebase, cPanel)
  trailingSlash: true,
  images: { unoptimized: true },
};
export default nextConfig;
