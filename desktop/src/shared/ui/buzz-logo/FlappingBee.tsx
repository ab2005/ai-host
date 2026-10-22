/**
 * Fork replacement for upstream's flapping bee: the AI-HOST arch mark whose dot
 * breathes slowly (see `.aihost-mark-dot` in brand/desktop/brand.css, which
 * respects reduced motion). Export name and props are unchanged.
 */
export function FlappingBee({ className }: { className?: string }) {
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
      <circle
        className="aihost-mark-dot"
        cx="48"
        cy="60"
        r="7"
        fill="#b54d32"
      />
    </svg>
  );
}
