import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";

const isPublicRoute = createRouteMatcher([
  '/',
  '/sign-in(.*)',
  '/sign-up(.*)'
]);

export default clerkMiddleware(async (auth, req) => {
  const { userId } = await auth();
  
  // If user is signed in and trying to access public routes, redirect to dashboard
  if (userId && isPublicRoute(req)) {
    const url = req.nextUrl.clone();
    
    // Only redirect if they're on the landing page, not if they're already authenticated
    if (url.pathname === '/') {
      return NextResponse.redirect(new URL('/', req.url));
    }
  }
  
  // For non-public routes, require authentication
  if (!isPublicRoute(req) && !userId) {
    return NextResponse.redirect(new URL('/', req.url));
  }
});

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    "/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)",
    // Always run for API routes
    "/(api|trpc)(.*)",
  ],
};
