"use client";

import { useState, useEffect, useCallback } from "react";
import {
  ChevronLeft,
  ChevronRight,
  QrCode,
  Shield,
  Database,
  Users,
  MapPin,
  Clock,
  FileText,
  Bell,
  Server,
  Lock,
  Layers,
  CheckCircle,
  AlertTriangle,
} from "lucide-react";

const slides = [
  { id: "title", type: "title" },
  { id: "overview", type: "overview" },
  { id: "features", type: "features" },
  { id: "tech-stack", type: "tech-stack" },
  { id: "security", type: "security" },
  { id: "workflow", type: "workflow" },
  { id: "ending", type: "ending" },
];

export default function SlideshowPage() {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [isAutoPlay, setIsAutoPlay] = useState(true);

  const nextSlide = useCallback(() => {
    setCurrentSlide((prev) => (prev + 1) % slides.length);
  }, []);

  const prevSlide = useCallback(() => {
    setCurrentSlide((prev) => (prev - 1 + slides.length) % slides.length);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight" || e.key === " ") {
        nextSlide();
        setIsAutoPlay(false);
      } else if (e.key === "ArrowLeft") {
        prevSlide();
        setIsAutoPlay(false);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [nextSlide, prevSlide]);

  useEffect(() => {
    if (!isAutoPlay) return;
    const interval = setInterval(nextSlide, 8000);
    return () => clearInterval(interval);
  }, [isAutoPlay, nextSlide]);

  return (
    <div className="fixed inset-0 flex flex-col bg-background text-foreground overflow-hidden">
      <div className="flex-1 flex items-center justify-center">
        <div className="w-full h-full max-w-[177.78vh] max-h-[56.25vw] aspect-video relative">
          {slides[currentSlide].type === "title" && <TitleSlide />}
          {slides[currentSlide].type === "overview" && <OverviewSlide />}
          {slides[currentSlide].type === "features" && <FeaturesSlide />}
          {slides[currentSlide].type === "tech-stack" && <TechStackSlide />}
          {slides[currentSlide].type === "security" && <SecuritySlide />}
          {slides[currentSlide].type === "workflow" && <WorkflowSlide />}
          {slides[currentSlide].type === "ending" && <EndingSlide />}
        </div>
      </div>

      {/* Navigation */}
      <div className="absolute bottom-6 left-1/2 -translate-x-1/2 flex items-center gap-4">
        <button
          onClick={() => {
            prevSlide();
            setIsAutoPlay(false);
          }}
          className="p-2 rounded-full bg-secondary/50 hover:bg-secondary transition-colors"
        >
          <ChevronLeft className="w-5 h-5" />
        </button>
        <div className="flex gap-2">
          {slides.map((_, i) => (
            <button
              key={i}
              onClick={() => {
                setCurrentSlide(i);
                setIsAutoPlay(false);
              }}
              className={`w-2 h-2 rounded-full transition-all ${
                i === currentSlide
                  ? "bg-accent w-6"
                  : "bg-muted-foreground/40 hover:bg-muted-foreground/60"
              }`}
            />
          ))}
        </div>
        <button
          onClick={() => {
            nextSlide();
            setIsAutoPlay(false);
          }}
          className="p-2 rounded-full bg-secondary/50 hover:bg-secondary transition-colors"
        >
          <ChevronRight className="w-5 h-5" />
        </button>
      </div>

      {/* Progress bar */}
      <div className="absolute top-0 left-0 right-0 h-1 bg-secondary">
        <div
          className="h-full bg-accent transition-all duration-300"
          style={{ width: `${((currentSlide + 1) / slides.length) * 100}%` }}
        />
      </div>

      {/* Slide number */}
      <div className="absolute top-6 right-8 text-muted-foreground font-medium">
        {String(currentSlide + 1).padStart(2, "0")} / {String(slides.length).padStart(2, "0")}
      </div>
    </div>
  );
}

function TitleSlide() {
  return (
    <div className="h-full flex flex-col items-center justify-center px-12 text-center relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 opacity-5">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 border border-foreground rounded-full" />
        <div className="absolute bottom-1/4 right-1/4 w-64 h-64 border border-foreground rounded-full" />
      </div>

      <div className="relative z-10">
        <div className="flex items-center justify-center gap-4 mb-8">
          <div className="p-4 bg-accent/20 rounded-2xl">
            <QrCode className="w-12 h-12 text-accent" />
          </div>
        </div>

        <p className="text-muted-foreground text-lg tracking-widest uppercase mb-4">
          Attendance Management System
        </p>

        <h1 className="text-7xl font-bold tracking-tight mb-6 text-balance">
          出席管理システム
        </h1>

        <p className="text-xl text-muted-foreground max-w-2xl mb-12">
          QRコードによるスマートな出席管理
          <br />
          教員・学生・管理者のためのオールインワンソリューション
        </p>

        <div className="flex items-center justify-center gap-8 text-sm text-muted-foreground">
          <span>大阪情報コンピュータ専門学校</span>
          <span className="w-1 h-1 rounded-full bg-muted-foreground" />
          <span>学内作品展 2026</span>
        </div>
      </div>
    </div>
  );
}

function OverviewSlide() {
  return (
    <div className="h-full flex flex-col px-16 py-12">
      <div className="mb-8">
        <p className="text-accent text-sm font-medium tracking-widest uppercase mb-2">
          Overview
        </p>
        <h2 className="text-5xl font-bold">システム概要</h2>
      </div>

      <div className="flex-1 grid grid-cols-2 gap-12">
        <div className="flex flex-col justify-center">
          <p className="text-xl text-muted-foreground leading-relaxed mb-8">
            学校向けの出席管理を、QR入室/退室・申請承認・監査ログ・レポートまで一体化したWebアプリケーションです。
          </p>

          <div className="space-y-4">
            <div className="flex items-start gap-4">
              <div className="p-2 bg-secondary rounded-lg shrink-0">
                <Users className="w-5 h-5 text-accent" />
              </div>
              <div>
                <h3 className="font-semibold mb-1">3つのロール</h3>
                <p className="text-sm text-muted-foreground">
                  教員・学生・管理者の権限に応じた機能提供
                </p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="p-2 bg-secondary rounded-lg shrink-0">
                <CheckCircle className="w-5 h-5 text-accent" />
              </div>
              <div>
                <h3 className="font-semibold mb-1">承認ワークフロー</h3>
                <p className="text-sm text-muted-foreground">
                  出席修正・確定・解除は承認フローを経由
                </p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="p-2 bg-secondary rounded-lg shrink-0">
                <FileText className="w-5 h-5 text-accent" />
              </div>
              <div>
                <h3 className="font-semibold mb-1">監査対応</h3>
                <p className="text-sm text-muted-foreground">
                  全ての出席変更・QRスキャンを記録
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="flex items-center justify-center">
          <div className="w-full max-w-md space-y-4">
            <div className="bg-card border border-border rounded-xl p-6">
              <h4 className="font-semibold mb-4 flex items-center gap-2">
                <MapPin className="w-4 h-4 text-accent" />
                OIC運用固定設定
              </h4>
              <div className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">校舎</span>
                  <span>大阪情報コンピュータ専門学校</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">住所</span>
                  <span>大阪市天王寺区上本町6-8-4</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">ジオフェンス</span>
                  <span>校内半径50m</span>
                </div>
              </div>
            </div>

            <div className="bg-card border border-border rounded-xl p-6">
              <h4 className="font-semibold mb-4 flex items-center gap-2">
                <Clock className="w-4 h-4 text-accent" />
                時限設定
              </h4>
              <div className="grid grid-cols-2 gap-2 text-sm">
                <span className="text-muted-foreground">1限</span>
                <span>09:10 - 10:40</span>
                <span className="text-muted-foreground">2限</span>
                <span>10:50 - 12:20</span>
                <span className="text-muted-foreground">3限</span>
                <span>13:10 - 14:40</span>
                <span className="text-muted-foreground">4限</span>
                <span>14:50 - 16:20</span>
                <span className="text-muted-foreground">5限</span>
                <span>16:30 - 18:00</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function FeaturesSlide() {
  const features = [
    {
      icon: QrCode,
      title: "QR出席登録",
      description: "署名トークン検証による安全な入退室記録",
    },
    {
      icon: FileText,
      title: "出席申請",
      description: "欠席・遅刻・公欠の申請と承認ワークフロー",
    },
    {
      icon: Clock,
      title: "早退判定",
      description: "滞在時間に基づく自動早退判定",
    },
    {
      icon: Shield,
      title: "監査ログ",
      description: "出席変更・QRスキャンの検索とCSV出力",
    },
    {
      icon: Bell,
      title: "通知機能",
      description: "メール・LINE・プッシュ通知対応",
    },
    {
      icon: Database,
      title: "レポート",
      description: "週次/日次の出席率推移と期末レポート",
    },
  ];

  return (
    <div className="h-full flex flex-col px-16 py-12">
      <div className="mb-8">
        <p className="text-accent text-sm font-medium tracking-widest uppercase mb-2">
          Features
        </p>
        <h2 className="text-5xl font-bold">主要機能</h2>
      </div>

      <div className="flex-1 grid grid-cols-3 gap-6">
        {features.map((feature, i) => (
          <div
            key={i}
            className="bg-card border border-border rounded-2xl p-8 flex flex-col hover:border-accent/50 transition-colors"
          >
            <div className="p-3 bg-secondary rounded-xl w-fit mb-6">
              <feature.icon className="w-8 h-8 text-accent" />
            </div>
            <h3 className="text-xl font-semibold mb-3">{feature.title}</h3>
            <p className="text-muted-foreground leading-relaxed">
              {feature.description}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}

function TechStackSlide() {
  const technologies = [
    {
      category: "Backend",
      items: [
        { name: "Ruby on Rails 8", desc: "最新のRailsフレームワーク" },
        { name: "Hotwire", desc: "Turbo + Stimulusでリアルタイム更新" },
        { name: "PostgreSQL", desc: "信頼性の高いリレーショナルDB" },
      ],
    },
    {
      category: "Frontend",
      items: [
        { name: "Tailwind CSS", desc: "ユーティリティファーストCSS" },
        { name: "Turbo Frames", desc: "部分更新でSPA体験" },
        { name: "Stimulus", desc: "軽量JavaScriptコントローラ" },
      ],
    },
    {
      category: "Infrastructure",
      items: [
        { name: "Render", desc: "クラウドホスティング" },
        { name: "Docker", desc: "コンテナ化された環境" },
        { name: "Puma", desc: "高性能Webサーバー" },
      ],
    },
  ];

  return (
    <div className="h-full flex flex-col px-16 py-12">
      <div className="mb-8">
        <p className="text-accent text-sm font-medium tracking-widest uppercase mb-2">
          Tech Stack
        </p>
        <h2 className="text-5xl font-bold">技術スタック</h2>
      </div>

      <div className="flex-1 grid grid-cols-3 gap-8">
        {technologies.map((tech, i) => (
          <div key={i} className="flex flex-col">
            <div className="flex items-center gap-3 mb-6">
              {tech.category === "Backend" && (
                <Server className="w-6 h-6 text-accent" />
              )}
              {tech.category === "Frontend" && (
                <Layers className="w-6 h-6 text-accent" />
              )}
              {tech.category === "Infrastructure" && (
                <Database className="w-6 h-6 text-accent" />
              )}
              <h3 className="text-2xl font-semibold">{tech.category}</h3>
            </div>
            <div className="space-y-4 flex-1">
              {tech.items.map((item, j) => (
                <div
                  key={j}
                  className="bg-card border border-border rounded-xl p-5 hover:border-accent/50 transition-colors"
                >
                  <h4 className="font-semibold mb-1">{item.name}</h4>
                  <p className="text-sm text-muted-foreground">{item.desc}</p>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-8 flex justify-center gap-6 text-sm text-muted-foreground">
        <span className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-accent" />
          Ruby 3.2+
        </span>
        <span className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-accent" />
          Rails 8.0
        </span>
        <span className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-accent" />
          PostgreSQL 15
        </span>
      </div>
    </div>
  );
}

function SecuritySlide() {
  const securityFeatures = [
    {
      icon: Lock,
      title: "署名トークン認証",
      description: "MessageVerifierによるQRトークンの署名・検証",
      detail: "有効期限付きの暗号化トークンで不正利用を防止",
    },
    {
      icon: MapPin,
      title: "位置情報検証",
      description: "ジオフェンスによる校内限定スキャン",
      detail: "GPS精度検証 + 校内50m範囲のみ有効",
    },
    {
      icon: Shield,
      title: "不正検知システム",
      description: "レート制限・トークン共有検知・IP監視",
      detail: "異常パターンを自動検出してブロック",
    },
    {
      icon: AlertTriangle,
      title: "アクセス制御",
      description: "ロールベースの権限管理",
      detail: "機能単位での細かな権限設定",
    },
  ];

  return (
    <div className="h-full flex flex-col px-16 py-12">
      <div className="mb-8">
        <p className="text-accent text-sm font-medium tracking-widest uppercase mb-2">
          Security
        </p>
        <h2 className="text-5xl font-bold">セキュリティ</h2>
      </div>

      <div className="flex-1 grid grid-cols-2 gap-8">
        <div className="space-y-6">
          {securityFeatures.map((feature, i) => (
            <div
              key={i}
              className="bg-card border border-border rounded-xl p-6 flex gap-5 hover:border-accent/50 transition-colors"
            >
              <div className="p-3 bg-secondary rounded-lg h-fit">
                <feature.icon className="w-6 h-6 text-accent" />
              </div>
              <div>
                <h3 className="font-semibold text-lg mb-1">{feature.title}</h3>
                <p className="text-muted-foreground mb-2">
                  {feature.description}
                </p>
                <p className="text-sm text-muted-foreground/70">
                  {feature.detail}
                </p>
              </div>
            </div>
          ))}
        </div>

        <div className="flex items-center justify-center">
          <div className="bg-card border border-border rounded-2xl p-8 w-full max-w-md">
            <h4 className="font-semibold text-lg mb-6 flex items-center gap-2">
              <Shield className="w-5 h-5 text-accent" />
              不正検知しきい値
            </h4>
            <div className="space-y-4">
              <div className="flex justify-between items-center py-3 border-b border-border">
                <span className="text-muted-foreground">失敗多発</span>
                <span className="font-mono bg-secondary px-3 py-1 rounded">
                  2分内に4回以上
                </span>
              </div>
              <div className="flex justify-between items-center py-3 border-b border-border">
                <span className="text-muted-foreground">同一IP集中</span>
                <span className="font-mono bg-secondary px-3 py-1 rounded">
                  1分内に8回以上
                </span>
              </div>
              <div className="flex justify-between items-center py-3 border-b border-border">
                <span className="text-muted-foreground">トークン共有</span>
                <span className="font-mono bg-secondary px-3 py-1 rounded">
                  2分内に2人以上
                </span>
              </div>
              <div className="flex justify-between items-center py-3">
                <span className="text-muted-foreground">遅刻判定</span>
                <span className="font-mono bg-secondary px-3 py-1 rounded">
                  授業開始+20分
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function WorkflowSlide() {
  return (
    <div className="h-full flex flex-col px-16 py-12">
      <div className="mb-8">
        <p className="text-accent text-sm font-medium tracking-widest uppercase mb-2">
          Workflow
        </p>
        <h2 className="text-5xl font-bold">出席登録フロー</h2>
      </div>

      <div className="flex-1 flex items-center">
        <div className="w-full">
          {/* Teacher flow */}
          <div className="mb-12">
            <h3 className="text-lg font-semibold mb-6 flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-accent" />
              教員の操作
            </h3>
            <div className="flex items-center gap-4">
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">1</div>
                <p className="font-medium">クラス選択</p>
                <p className="text-sm text-muted-foreground mt-1">
                  担当クラスを選ぶ
                </p>
              </div>
              <ChevronRight className="w-6 h-6 text-muted-foreground shrink-0" />
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">2</div>
                <p className="font-medium">QR発行</p>
                <p className="text-sm text-muted-foreground mt-1">
                  署名トークン生成
                </p>
              </div>
              <ChevronRight className="w-6 h-6 text-muted-foreground shrink-0" />
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">3</div>
                <p className="font-medium">QR表示</p>
                <p className="text-sm text-muted-foreground mt-1">
                  学生に提示する
                </p>
              </div>
              <ChevronRight className="w-6 h-6 text-muted-foreground shrink-0" />
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">4</div>
                <p className="font-medium">出席確認</p>
                <p className="text-sm text-muted-foreground mt-1">
                  リアルタイム反映
                </p>
              </div>
            </div>
          </div>

          {/* Student flow */}
          <div>
            <h3 className="text-lg font-semibold mb-6 flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-accent" />
              学生の操作
            </h3>
            <div className="flex items-center gap-4">
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">1</div>
                <p className="font-medium">QRスキャン</p>
                <p className="text-sm text-muted-foreground mt-1">
                  トークン入力
                </p>
              </div>
              <ChevronRight className="w-6 h-6 text-muted-foreground shrink-0" />
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">2</div>
                <p className="font-medium">位置情報取得</p>
                <p className="text-sm text-muted-foreground mt-1">
                  GPS精度検証
                </p>
              </div>
              <ChevronRight className="w-6 h-6 text-muted-foreground shrink-0" />
              <div className="bg-card border border-border rounded-xl p-5 flex-1 text-center">
                <div className="text-3xl mb-2">3</div>
                <p className="font-medium">トークン検証</p>
                <p className="text-sm text-muted-foreground mt-1">
                  署名・履修確認
                </p>
              </div>
              <ChevronRight className="w-6 h-6 text-muted-foreground shrink-0" />
              <div className="bg-card border border-accent/50 rounded-xl p-5 flex-1 text-center bg-accent/10">
                <div className="text-3xl mb-2 text-accent">OK</div>
                <p className="font-medium">出席登録完了</p>
                <p className="text-sm text-muted-foreground mt-1">
                  入室時刻記録
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function EndingSlide() {
  return (
    <div className="h-full flex flex-col items-center justify-center px-12 text-center relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 opacity-5">
        <div className="absolute top-1/3 left-1/3 w-[600px] h-[600px] border border-foreground rounded-full" />
        <div className="absolute bottom-1/3 right-1/3 w-[400px] h-[400px] border border-foreground rounded-full" />
      </div>

      <div className="relative z-10">
        <p className="text-accent text-lg tracking-widest uppercase mb-8">
          Thank you for watching
        </p>

        <h2 className="text-6xl font-bold mb-8 text-balance">
          ご覧いただき
          <br />
          ありがとうございました
        </h2>

        <div className="flex flex-col items-center gap-6 mb-12">
          <div className="flex items-center gap-6 text-muted-foreground">
            <span className="flex items-center gap-2">
              <Server className="w-4 h-4" />
              Rails 8
            </span>
            <span className="w-1 h-1 rounded-full bg-muted-foreground" />
            <span className="flex items-center gap-2">
              <Database className="w-4 h-4" />
              PostgreSQL
            </span>
            <span className="w-1 h-1 rounded-full bg-muted-foreground" />
            <span className="flex items-center gap-2">
              <QrCode className="w-4 h-4" />
              QR認証
            </span>
            <span className="w-1 h-1 rounded-full bg-muted-foreground" />
            <span className="flex items-center gap-2">
              <MapPin className="w-4 h-4" />
              位置認証
            </span>
          </div>
        </div>

        <div className="text-muted-foreground">
          <p className="text-lg font-medium">大阪情報コンピュータ専門学校</p>
          <p className="text-sm mt-2">学内作品展 2026</p>
        </div>
      </div>
    </div>
  );
}
