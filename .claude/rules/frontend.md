# Frontend Rules — Next.js + React + TypeScript

> Standards for the approved frontend stack. See [`tech-stack.md`](tech-stack.md) for the full stack rationale and decision tables.

---

## Stack Quick Reference

| Concern | Choice |
|---------|--------|
| Public site (SEO) | Next.js 14+ (App Router) |
| Admin/Dashboard | React + Vite (SPA) |
| Language | TypeScript (strict mode) |
| UI components | shadcn/ui + Radix UI |
| Styling | Tailwind CSS |
| State | Zustand |
| Server state | TanStack Query (React Query) |
| Forms | React Hook Form + Zod |
| Auth (Next.js) | NextAuth.js |
| Testing | Vitest + React Testing Library |
| E2E | Playwright |

---

## TypeScript

### Strict mode is mandatory

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### Prefer `type` for unions/intersections, `interface` for objects extended elsewhere

```ts
// Unions / mapped types → type
type UserRole = "user" | "admin" | "superAdmin";
type Nullable<T> = T | null;

// Object shapes that may be extended → interface
interface UserProps {
  id: string;
  email: string;
}
```

### Never use `any` — prefer `unknown` and narrow

```ts
// Bad
function parse(input: any) { return JSON.parse(input); }

// Good
function parse(input: unknown): User {
  const data = JSON.parse(String(input));
  return UserSchema.parse(data); // validate with Zod
}
```

---

## Component Patterns

### Server Components by default (Next.js App Router)

```tsx
// app/users/page.tsx — Server Component (no "use client")
import { getUsers } from "@/lib/api/users";

export default async function UsersPage() {
  const users = await getUsers();
  return <UserList users={users} />;
}
```

### Use `"use client"` only when you need:
- `useState`, `useEffect`, `useReducer`
- Event handlers (`onClick`, `onChange`)
- Browser APIs (`window`, `localStorage`)
- React Context

### Component file structure

```tsx
// components/user-card.tsx
"use client";

import { cn } from "@/lib/utils";

interface UserCardProps {
  user: { id: string; name: string; email: string };
  variant?: "compact" | "full";
  className?: string;
  onSelect?: (id: string) => void;
}

export function UserCard({
  user,
  variant = "full",
  className,
  onSelect,
}: UserCardProps) {
  return (
    <article
      className={cn(
        "rounded-lg border p-4",
        variant === "compact" && "p-2",
        className,
      )}
      onClick={() => onSelect?.(user.id)}
    >
      <h3 className="font-semibold">{user.name}</h3>
      <p className="text-sm text-muted-foreground">{user.email}</p>
    </article>
  );
}
```

### Naming

| Element | Convention | Example |
|---------|------------|---------|
| Component files | kebab-case | `user-card.tsx` |
| Component name (export) | PascalCase | `UserCard` |
| Hooks | camelCase, `use` prefix | `useDebouncedValue` |
| Props interfaces | `{Component}Props` | `UserCardProps` |
| Boolean props | `is/has/can` prefix | `isLoading`, `hasError` |
| Event handler props | `on{Event}` | `onSelect`, `onSubmit` |
| Event handlers (internal) | `handle{Event}` | `handleClick` |

---

## State Management

### Local state → `useState` / `useReducer`

For ephemeral UI state (open/closed, hover, input value).

### Cross-component state → Zustand

```ts
// stores/cart-store.ts
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface CartState {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clear: () => void;
}

export const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      items: [],
      addItem: (item) => set((s) => ({ items: [...s.items, item] })),
      removeItem: (id) =>
        set((s) => ({ items: s.items.filter((i) => i.id !== id) })),
      clear: () => set({ items: [] }),
    }),
    { name: "cart-storage" },
  ),
);

// Usage — selector pattern to avoid re-renders
const itemCount = useCartStore((s) => s.items.length);
```

### Server state → TanStack Query (NEVER store in Zustand)

```ts
// hooks/use-users.ts
import { useQuery } from "@tanstack/react-query";

export function useUsers() {
  return useQuery({
    queryKey: ["users"],
    queryFn: () => fetch("/api/v1/users").then((r) => r.json()),
    staleTime: 5 * 60 * 1000, // 5 min
  });
}

// Mutations
import { useMutation, useQueryClient } from "@tanstack/react-query";

export function useCreateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateUserInput) =>
      fetch("/api/v1/users", {
        method: "POST",
        body: JSON.stringify(input),
      }).then((r) => r.json()),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] }),
  });
}
```

### Query key conventions

```ts
// Hierarchical, array-based
["users"]                            // list
["users", { status: "active" }]      // filtered list
["users", userId]                    // detail
["users", userId, "orders"]          // nested resource
```

---

## Forms — React Hook Form + Zod

```tsx
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const CreateUserSchema = z.object({
  email: z.string().email("Invalid email"),
  name: z.string().min(2).max(100),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .regex(/[A-Z]/, "Must contain uppercase letter")
    .regex(/[0-9]/, "Must contain digit"),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;

export function CreateUserForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<CreateUserInput>({
    resolver: zodResolver(CreateUserSchema),
  });

  const onSubmit = async (data: CreateUserInput) => {
    await fetch("/api/v1/users", { method: "POST", body: JSON.stringify(data) });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <input {...register("email")} aria-invalid={!!errors.email} />
      {errors.email && <p role="alert">{errors.email.message}</p>}

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Creating…" : "Create"}
      </button>
    </form>
  );
}
```

> **Rule:** the same Zod schema can be reused on the server (Next.js API routes / Server Actions) to validate inputs — single source of truth.

---

## Styling — Tailwind CSS

### Use `cn()` helper for conditional classes

```ts
// lib/utils.ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### Extract repeated patterns into components, not `@apply`

```tsx
// Bad — magic CSS class
<div className="card-primary">…</div>

// Good — typed React component
<Card variant="primary">…</Card>
```

### Class order convention (enforced by `prettier-plugin-tailwindcss`)

`layout → box-model → typography → visual → state`

```tsx
<div className="flex items-center gap-2 p-4 text-sm font-medium text-gray-900 hover:bg-gray-50">
```

---

## Data Fetching Patterns

### Server Components: fetch directly

```tsx
// app/users/page.tsx
export default async function UsersPage() {
  const res = await fetch(`${process.env.API_URL}/users`, {
    next: { revalidate: 60 }, // ISR
  });
  const users = await res.json();
  return <UserList users={users} />;
}
```

### Client Components: use TanStack Query (never raw `useEffect + fetch`)

```tsx
// Bad — manual loading/error/refetch
useEffect(() => { fetch(...) }, []);

// Good — TanStack Query handles cache, retries, dedup
const { data, error, isPending } = useQuery({ queryKey: [...], queryFn: ... });
```

### Never call backend from client with secrets

Use Next.js Route Handlers or Server Actions as a BFF layer when the call needs a server-only token.

---

## Routing (Next.js App Router)

### Folder structure

```
app/
├── (marketing)/            # Group — no URL segment
│   ├── page.tsx            # /
│   └── pricing/page.tsx    # /pricing
├── (app)/
│   ├── layout.tsx          # Auth-protected layout
│   └── dashboard/
│       ├── page.tsx        # /dashboard
│       └── @sidebar/       # Parallel route
├── users/
│   ├── page.tsx            # /users
│   ├── [id]/page.tsx       # /users/:id
│   └── loading.tsx         # Suspense fallback
├── api/v1/
│   └── users/route.ts      # /api/v1/users
└── layout.tsx              # Root layout
```

### Loading & error boundaries

Every async route should have a sibling `loading.tsx` and `error.tsx`.

---

## Accessibility (WCAG 2.1 AA)

- **Semantic HTML first** — use `<button>`, `<nav>`, `<article>`, not `<div onClick>`
- All form inputs need an associated `<label>`
- Interactive elements must be keyboard-reachable (`tabindex` is rarely needed if using semantic HTML)
- Icons-only buttons need `aria-label`
- Color contrast ≥ 4.5:1 (normal text), ≥ 3:1 (large text)
- `aria-live="polite"` for status messages, `role="alert"` for errors
- Test with keyboard navigation and a screen reader (VoiceOver / NVDA)

See [`accessibility-checklist.md`](../references/accessibility-checklist.md) for the full WCAG checklist.

---

## Performance

### Core Web Vitals targets

| Metric | Good |
|--------|------|
| LCP (Largest Contentful Paint) | < 2.5s |
| INP (Interaction to Next Paint) | < 200ms |
| CLS (Cumulative Layout Shift) | < 0.1 |

### Required practices

- Use Next.js `<Image>` for all images (auto WebP, lazy loading, sizing)
- Dynamic `import()` for heavy client components below the fold
- Server Components by default — only opt into client when necessary
- Avoid waterfalls — fetch in parallel with `Promise.all`
- Memoize with `useMemo` / `useCallback` **only when measurably needed**
- Use `React.lazy` + `<Suspense>` for code-splitting in SPA (Vite)

```tsx
// Heavy chart loaded only when needed
const Chart = dynamic(() => import("@/components/chart"), {
  loading: () => <ChartSkeleton />,
  ssr: false,
});
```

---

## Error Handling

### Client-side

```tsx
// app/users/[id]/error.tsx
"use client";

export default function Error({
  error,
  reset,
}: { error: Error; reset: () => void }) {
  return (
    <div role="alert">
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

### Server-side — consume backend `ProblemDetails`

```ts
// lib/api/fetcher.ts — match the C# ProblemDetails contract
type ProblemDetails = {
  status: number;
  title: string;
  detail: string;
  code?: string;
  errors?: Record<string, string[]>;
  traceId?: string;
};

export async function apiFetch<T>(input: string, init?: RequestInit): Promise<T> {
  const res = await fetch(input, init);
  if (!res.ok) {
    const problem = (await res.json()) as ProblemDetails;
    throw new ApiError(problem);
  }
  return res.json() as Promise<T>;
}
```

---

## Testing

| Layer | Tool | What to test |
|-------|------|--------------|
| Unit | Vitest | Pure functions, hooks (with `renderHook`) |
| Component | React Testing Library | User-visible behavior, not implementation |
| E2E | Playwright | Critical user journeys |

### React Testing Library principles

```tsx
// Bad — testing implementation details
expect(component.state.isOpen).toBe(true);

// Good — testing what the user sees
expect(screen.getByRole("dialog")).toBeVisible();
expect(screen.getByRole("button", { name: /close/i })).toBeEnabled();
```

> Always query by **role > label > text > testId** (in that priority order).

---

## File & Folder Conventions

```
src/
├── app/                    # Next.js App Router (or src/pages for SPA)
├── components/
│   ├── ui/                 # shadcn/ui primitives
│   └── features/           # Feature-specific components
├── hooks/                  # Custom hooks (use-*.ts)
├── lib/                    # Utilities, API clients
│   ├── api/                # Typed API fetchers
│   ├── utils.ts            # cn(), formatters
│   └── validations/        # Zod schemas
├── stores/                 # Zustand stores
└── types/                  # Shared TypeScript types
```

---

## Checklist

- [ ] TypeScript `strict: true` enabled
- [ ] No `any` — `unknown` + narrowing instead
- [ ] Server Components by default; `"use client"` only when needed
- [ ] Zustand for local cross-component state, TanStack Query for server state
- [ ] Forms validated with Zod (schema reused server-side)
- [ ] `<Image>` for all images
- [ ] Keyboard navigation works on every interactive element
- [ ] `error.tsx` and `loading.tsx` exist for async routes
- [ ] Backend errors rendered via `ProblemDetails` contract
- [ ] Components tested by role/label, not implementation
