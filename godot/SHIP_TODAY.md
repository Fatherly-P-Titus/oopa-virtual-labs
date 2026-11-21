# Ship OOPA Virtual Labs to the web — TODAY

Godot 4.7 · GL Compatibility · Web export (threads **off**)

## 1) Export from Godot (required — cannot skip)

1. Open this project in **Godot 4.7**.
2. **Editor → Manage Export Templates → Download and Install**.
3. **Project → Export → Web** (preset included).
4. Path: `build/web/index.html` → **Export Project**.

Output folder: `build/web/` (`index.html`, `.js`, `.pck`, `.wasm`, …).

## 2) Deploy (fastest paths)

### A) itch.io (often quickest)
1. New project → **HTML5**.
2. Zip **contents** of `build/web/`.
3. Upload · “played in the browser” · 1280×720.

### B) Vercel
```bash
cd build/web
cp ../web_host/vercel.json .
npx vercel --prod
```
Or drag-and-drop `build/web` at vercel.com/new.

### C) Netlify
```bash
cd build/web
cp ../web_host/netlify.toml .
cp ../web_host/_headers .
npx netlify deploy --prod --dir=.
```

## 3) Smoke on the live URL
- Splash → Main Menu → open a lab
- Instructor Login: `AdminStaff/001` / `12346`
- Student Exam only after you create an exam in-browser

**Web note:** `user://oopa/` data is **per browser**, not a shared campus server.

## 4) Share
Staff: URL + instructor credentials.  
Students: URL + 6-digit exam code (must be on roster).
