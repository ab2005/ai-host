import type { CSSProperties } from "react";
import "./buzz-logo-animation.css";

/**
 * Fork replacement for upstream's morphing bee animation (about 700 lines of
 * SMIL). Renders the AI-HOST arch mark; when asked to loop or add texture, the
 * dot breathes. The prop types are kept so every caller (boot screen, loading
 * states, agent liveness) is unchanged. See FORK.md ("Visual identity").
 */
export type BuzzLogoAnimationProps = {
  ariaLabel?: string;
  className?: string;
  fullScreen?: boolean;
  loop?: boolean;
  loopRestSeconds?: number;
  reverse?: boolean;
  showBackground?: boolean;
  style?: CSSProperties;
  textured?: boolean;
  variant?: string;
};

export default function BuzzLogoAnimation({
  ariaLabel = "AI-HOST logo",
  className = "",
  fullScreen = true,
  loop = false,
  showBackground = true,
  style,
  textured = true,
}: BuzzLogoAnimationProps) {
  const classes = [
    "buzz-logo",
    fullScreen && "buzz-logo--screen",
    !fullScreen && "buzz-logo--compact",
    showBackground && "buzz-logo--background",
    className,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div className={classes} style={style} role="img" aria-label={ariaLabel}>
      <svg
        className="buzz-logo__mark"
        viewBox="0 0 96 96"
        width="96"
        height="96"
        fill="none"
        aria-hidden="true"
      >
        <path
          d="M24 76V46a24 24 0 0 1 48 0v30"
          stroke="currentColor"
          strokeWidth="6"
          strokeLinecap="round"
        />
        <circle
          className={loop || textured ? "aihost-mark-dot" : undefined}
          cx="48"
          cy="60"
          r="7"
          fill="#b54d32"
        />
      </svg>
    </div>
  );
}
