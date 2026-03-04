# APK Download Site (Vercel)

Site statique avec bouton unique `Telecharger`.
Le script JS detecte Android + ABI puis lance le bon APK.

## 1) Rebuild APK Flutter

```bash
flutter build apk --split-per-abi
```

## 2) Copier les APK dans le site

```bash
./scripts/prepare_apk_site.sh
```

## 3) Deploy Vercel

```bash
# Preview deploy
./scripts/deploy_apk_site_vercel.sh

# Production deploy
./scripts/deploy_apk_site_vercel.sh --prod
```

## Prerequis

- Node.js / npm
- Vercel CLI: `npm i -g vercel`
- Auth Vercel: `vercel login`
