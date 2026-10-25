# Kaam Fast Partner

Flutter partner app UI for Kaam Fast Partner.

## Design
- Primary: `#000666` / `#1A237E`
- Accent: `#6F43C0`
- Fonts: Hanken Grotesk + Inter
- Flow: Splash → Welcome → Role → Login/OTP → Home shell

## Roles
- **Delivery Partner** — parcel jobs (Accept / Start / Complete)
- **Business Partner** — laundry hub orders (Assign Rider)
- **Service Partner** — UI present (Coming focus later)

## Run
```bash
flutter pub get
flutter run
```

Demo OTP: `1234`

## Auth + availability

1. Login OTP via `POST /api/v1/partner/auth/*`
2. Online toggle → `POST /api/v1/partner/availability` `{ "is_online": true|false }`
3. Backend also syncs Firebase RTDB presence when Admin → Third Party has:
   - Realtime Database URL
   - Database secret

Paths written:
- `partners/partner_{id}/presence`
- `presence/partner_{id}`

Offline jobs: backend already hides available bookings when `is_online` is false.

## Display over other apps (Android)

Profile → **Display over other apps** toggle:
1. Opens system permission if needed
2. Shows floating ONLINE bubble while partner is online
3. Hides bubble when offline / logout

Requires Android `SYSTEM_ALERT_WINDOW`.
