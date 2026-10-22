/**
 * The AI-HOST mark: an arch (the ∩ from New-I's "where new ∩ now") read as a
 * doorway, with a terracotta dot inside. Fork replacement for upstream's bee;
 * the export name and props are unchanged so call sites need no edits.
 * The arch follows `currentColor`; the dot keeps the brand accent.
 */
export function BuzzMark({ className }: { className?: string }) {
  return (
    <svg
      aria-hidden="true"
      className={["buzz-mark", className].filter(Boolean).join(" ")}
      viewBox="0 0 96 96"
      fill="none"
    >
      <path
        d="M24 76V46a24 24 0 0 1 48 0v30"
        stroke="currentColor"
        strokeWidth="6"
        strokeLinecap="round"
      />
      <circle cx="48" cy="60" r="7" fill="#b54d32" />
    </svg>
  );
}
