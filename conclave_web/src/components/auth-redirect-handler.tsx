"use client";

import { useEffect } from "react";
import { useUser } from "@clerk/nextjs";
import { useRouter } from "next/navigation";

export function AuthRedirectHandler() {
  const { isLoaded, user } = useUser();
  const router = useRouter();

  useEffect(() => {
    if (isLoaded && user) {
      // Force a refresh to ensure the authenticated state is properly recognized
      // This is especially important for mobile browsers
      const hasRefreshed = sessionStorage.getItem('auth-refreshed');
      
      if (!hasRefreshed) {
        sessionStorage.setItem('auth-refreshed', 'true');
        router.refresh();
      }
    }
  }, [isLoaded, user, router]);

  useEffect(() => {
    // Clean up the refresh flag when the component unmounts or user signs out
    if (isLoaded && !user) {
      sessionStorage.removeItem('auth-refreshed');
    }
  }, [isLoaded, user]);

  return null;
}