import "./globals.css"
import { Inter as FontSans } from "next/font/google"
import { PropsWithChildren } from 'react';
import { cn } from "@/lib/utils"
import { WalletProvider } from "@/components/WalletProvider";
import { Toaster } from "@/components/ui/toaster";
//import { Toaster } from "@/components/ui/toaster";

const fontSans = FontSans({
  subsets: ["latin"],
  variable: "--font-sans",
})

type RootLayoutProps = PropsWithChildren<{}>;
export default function RootLayout({ children }: RootLayoutProps) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head />
      <body
        className={cn(
          "min-h-screen bg-background font-sans antialiased",
          fontSans.variable
        )}
      >
            <WalletProvider>
              {children}
              <Toaster />
              
            </WalletProvider>
      </body>
    </html>
  )
}

