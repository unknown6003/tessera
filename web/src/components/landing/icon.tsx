import {
  PieChart,
  Gauge,
  Sparkles,
  Copy,
  Code,
  Layers,
  FileSearch,
  AppWindow,
  Eraser,
  HardDrive,
  ShieldCheck,
  Lock,
  Cpu,
  Zap,
  Search,
  Trash2,
  Eye,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'

const MAP: Record<string, LucideIcon> = {
  PieChart,
  Gauge,
  Sparkles,
  Copy,
  Code,
  Layers,
  FileSearch,
  AppWindow,
  Eraser,
  HardDrive,
  ShieldCheck,
  Lock,
  Cpu,
  Zap,
  Search,
  Trash2,
  Eye,
}

export function Icon({
  name,
  className,
}: {
  name: string
  className?: string
}) {
  const C = MAP[name] ?? Sparkles
  return <C className={className} strokeWidth={1.6} />
}
