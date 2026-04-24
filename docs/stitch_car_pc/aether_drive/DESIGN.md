# Design System Document: Automotive Tactile Maximalism

## 1. Overview & Creative North Star: "The Kinetic Cockpit"

This design system is engineered for the high-stakes, high-speed environment of a CarPC. Our Creative North Star is **The Kinetic Cockpit**. We are moving away from the "flat" trend of mobile apps and returning to a hyper-functional, high-tech tactile reality. 

The system breaks the "template" look through **Tactile Maximalism**. We treat the screen not as a flat piece of glass, but as a physical control deck. By using ultra-dark OLED blacks (`#0e0e0e`) and layering them with neon accents, we create a sense of infinite depth. Layouts should favor **intentional asymmetry**—placing primary driving controls (Media, Nav) in large, dominant blocks while secondary telemetry offsets them in tighter, technical clusters. This is not just a UI; it is an instrument cluster.

---

## 2. Colors: Neon on Void

The palette is built for zero light pollution and maximum glanceability.

- **The Primary Accents:** `primary` (#81ecff) and `secondary` (#ff51fa) are our "active" energies. They represent the "glow" of a futuristic engine.
- **The "No-Line" Rule:** Borders are strictly forbidden for sectioning. To separate the Music Player from the Map, use a shift from `surface` (#0e0e0e) to `surface_container_low` (#131313). Let the void define the structure.
- **Surface Hierarchy & Nesting:** Think of the UI as a physical dashboard.
    - **Base Level:** `surface` (#0e0e0e) - The deep background.
    - **Plates:** `surface_container` (#191919) - The raised panels holding controls.
    - **Active Buttons:** `surface_container_highest` (#262626) - The most "pressed forward" interactive elements.
- **The "Glass & Gradient" Rule:** To achieve the "cyber" vibe, use `surface_bright` with a 40% opacity and a 20px backdrop-blur for floating overlays. CTAs must use a linear gradient from `primary` (#81ecff) to `primary_container` (#00e3fd) to simulate a light-emissive physical material.

---

## 3. Typography: Technical Authority

We utilize two high-performance typefaces to balance character with data-heavy clarity.

- **Display & Headlines (Space Grotesk):** This is our "Technical" voice. The wide apertures and bold weights ensure that speed and temperature are readable in a split second at 70mph.
- **Body & Titles (Manrope):** Our "Functional" voice. Highly legible at smaller sizes for track listings or settings menus.
- **Hierarchy as Brand:** Use `display-lg` for the most critical metric (e.g., Speed) and `label-md` for technical sub-data. The massive scale contrast between a `display-lg` speedo and a `label-sm` timestamp creates an editorial, high-end automotive feel.

---

## 4. Elevation & Depth: The Tactile Stack

In this system, "Elevation" is a lighting effect, not just a shadow.

- **The Layering Principle:** Stack `surface_container_lowest` for recessed areas (like a "well" for a slider) and `surface_container_high` for things you can touch.
- **Ambient Shadows:** Standard drop shadows are too "web-like." Instead, use a "Glow Shadow." Use the `primary` or `secondary` color at 10% opacity with a 30px blur. This makes the button appear to be emitting light onto the dashboard.
- **The "Ghost Border":** If a button needs more definition against a dark background, use `outline_variant` at 15% opacity. This creates a "specular highlight" on the edge of the physical object rather than a flat border.
- **Tactile Depth:** Every interactive element must have a 1px inner-shadow (top-left) using `on_surface` at 10% to simulate a chamfered edge catching light.

---

## 5. Components: Engineered for the Hand

### Buttons (Tactile Triggers)
- **Primary:** High-contrast `primary` gradient. Minimum size: 80x80dp. Use `xl` (0.75rem) corner radius. On press, the element should "sink" by removing the glow shadow.
- **Secondary:** `surface_container_highest` background with a `primary` "Ghost Border."
- **Tertiary:** Text-only using `primary_dim`. Reserved for non-critical "back" actions.

### Input Fields (The Data Wells)
- Inputs should appear recessed. Use `surface_container_lowest` with a subtle inner glow. 
- **Error State:** Use `error` (#ff716c) for the text and a heavy `error_container` glow to draw the eye immediately.

### Cards & Lists (Seamless Panels)
- **Zero Dividers:** To separate list items (e.g., Radio Stations), use a vertical gap of 12px. The gap reveals the `surface` (true black) beneath, creating a natural separation.
- **Leading Elements:** Album art or icons should use the `lg` (0.5rem) radius to feel like inset physical tiles.

### Automotive Specific: The "Quick-Action" Orbital
- A floating, semi-transparent glass circle (`surface_bright` with backdrop blur) that houses the most used functions (Home, Voice, Mute). This remains anchored to the driver's closest edge.

---

## 6. Do's and Don'ts

### Do:
- **Do** prioritize touch targets. If a button is smaller than 76dp, it is a safety hazard.
- **Do** use "True Black" (#000000) for the `surface_container_lowest` to save battery and reduce cabin glare.
- **Do** use Neon Magenta (`secondary`) sparingly for "excitement" features (e.g., Sport Mode).

### Don't:
- **Don't** use pure white (#ffffff) for large blocks of text; it causes "haloing" against black. Use `on_surface_variant` (#ababab) for long-form content.
- **Don't** use 1px solid white borders. They look cheap and digital. Use background tonal shifts.
- **Don't** use animations that take longer than 200ms. In a car, the interface must feel instantaneous.

---

## 7. Designer Note: Embracing the "Glow"

When designing layouts, imagine the screen is the only light source in a dark cabin. Every `primary` element should feel like a neon tube. Use gradients that move from "Cyan" to "Deep Blue" to give the UI "soul." If the layout feels flat, you aren't using enough `surface-container` nesting. Layer your panels until the UI feels like a physical piece of hardware.