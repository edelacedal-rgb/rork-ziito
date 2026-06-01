import { PRIORITY_META, type PriorityLevel } from "@/lib/ziito-types";
import { colorAlpha, colorVar } from "@/lib/ziito-color";

export function PriorityBadge({ priority }: { priority: PriorityLevel }) {
  const meta = PRIORITY_META[priority];
  return (
    <span
      className="rounded-full px-2 py-0.5 text-[10px] font-semibold"
      style={{ color: colorVar(meta.colorHex), backgroundColor: colorAlpha(meta.colorHex, 0.12) }}
    >
      {meta.shortLabel}
    </span>
  );
}
