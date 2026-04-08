# asset_note

AssetNote is a Flutter app to manage assets by category and month.

## Requirements

- Flutter SDK
- Dart SDK (defined by this project)
- Supabase project (URL + anon key)

## Setup

Install dependencies:

```bash
flutter pub get
```

## Run

Set Supabase credentials using `--dart-define`:

```bash
flutter run ^
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

PowerShell example:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

### Optional: use `--dart-define-from-file`

If you do not want to pass keys every time, create `env.json` in the project root:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_ANON_KEY"
}
```

Run:

```powershell
flutter run --dart-define-from-file=env.json
```

Build examples:

```powershell
flutter build apk --dart-define-from-file=env.json
flutter build web --dart-define-from-file=env.json
```

Do not commit real credentials. Keep `env.json` local only.

## Useful Commands

- Analyze: `flutter analyze`
- Test: `flutter test`
- Build Android: `flutter build apk`
- Build Web: `flutter build web`

## Notes

- Current month data is stored in `assets`.
- Monthly snapshots are stored in `assets_history`.
- Monthly lock state is stored in `monthly_lock`.
