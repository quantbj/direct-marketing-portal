import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Direct Marketing Contracts",
  description: "Portal for direct marketing contracts",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
