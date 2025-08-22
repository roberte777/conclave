import { SignUp } from '@clerk/nextjs'

export default function Page() {
  return (
    <div className="flex items-center justify-center min-h-[calc(100vh-4rem)]">
      <SignUp 
        afterSignUpUrl="/"
        redirectUrl="/"
        appearance={{
          elements: {
            rootBox: "mx-auto",
            card: "shadow-lg",
          },
        }}
      />
    </div>
  )
}