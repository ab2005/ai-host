import { BuzzMark } from "@/shared/ui/buzz-logo/BuzzMark";

/**
 * Fork replacement for upstream's animated bee field on the start page: the
 * AI-HOST mark top-left and a quiet concentric-line artwork bottom-right,
 * echoing the line sculpture on new-i.ai. Export name is unchanged.
 */
export function LandingBees() {
  return (
    <div
      aria-hidden
      className="pointer-events-none absolute inset-0 overflow-hidden"
    >
      <span className="absolute left-6 top-12 block w-11 text-foreground">
        <BuzzMark className="h-auto w-full" />
      </span>
      <svg
        aria-hidden="true"
        className="absolute -bottom-10 -right-10 h-[420px] w-[420px] text-muted-foreground"
        viewBox="0 0 400 400"
        fill="none"
        stroke="currentColor"
        strokeWidth="1"
      >
        <g opacity="0.4">
          {[60, 80, 100, 120, 140, 160, 180, 200].map((r) => (
            <circle key={r} cx="260" cy="260" r={r} />
          ))}
        </g>
        <circle cx="260" cy="260" r="12" fill="#b54d32" stroke="none" />
      </svg>
    </div>
  );
}
