import type { Metadata } from "next";
import { Noto_Sans_JP } from "next/font/google";
import "./globals.css";

const notoSansJP = Noto_Sans_JP({
  subsets: ["latin"],
  variable: "--font-sans",
  weight: ["400", "500", "600", "700", "900"],
});

export const metadata: Metadata = {
  title: "出席管理システム | 学内作品展",
  description: "大阪情報コンピュータ専門学校 学内作品展 - QRコード出席管理システム",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja" className="dark">
      <body className={`${notoSansJP.variable} font-sans antialiased bg-background text-foreground`}>
        {children}
      </body>
    </html>
  );
}
