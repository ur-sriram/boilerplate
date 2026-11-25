# Junie UI & Motion Guidelines

These guidelines define UI aesthetics, accessibility requirements, and motion standards for JetBrains Junie in this project.

## 1. Design Steering & Vocabulary
When refining user interfaces, interpret and apply standard steering verbs:
- **bolder**: Increase typographical contrast, amplify visual hierarchy, strengthen focal points.
- **quieter**: Subdue background contrast, reduce font weights, increase whitespace breathing room.
- **polish**: Tighten pixel alignment, normalize border-radii, ensure consistent padding scales.
- **typeset**: Enforce modular typographic scales, rhythm, and proportional leading.

## 2. Anti-Slop Finish Gate
Every UI component must pass these finish gate criteria before acceptance:
- **Zero Generic Template Tropes**: Avoid generic AI-generated hero layouts, unnecessary gradient meshes, and empty buzzwords.
- **WCAG AA Compliance**: Foreground and background color pairs must meet minimum 4.5:1 contrast ratio for body text and 3:1 for large text.
- **Interactive State Completeness**: All actionable elements must provide explicit `:hover`, `:focus-visible`, `:active`, and `aria-disabled` states.

## 3. Motion & Animation Standards
- Animations must maintain 60fps / 120fps performance on standard hardware.
- Use GPU-accelerated CSS properties (`transform`, `opacity`) exclusively for transitions.
- Honor user motion preferences via `@media (prefers-reduced-motion: reduce)`.
- Use spring physics curves rather than linear timing for organic UI feedback.
