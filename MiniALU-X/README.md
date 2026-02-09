# MiniALU-X

This repo contains two layers:

- `assembly/`: the NASM (macOS x86_64 Mach-O) backend simulator (unchanged).
- `ui/`: a TypeScript/Next.js frontend scaffold (work in progress).

## Assembly (backend)

Build:

```sh
cd assembly
make
./bin/minialu-x
```

## UI (frontend)

Setup and run:

```sh
cd ui
npm install
npm run dev
```

