# Maximus Real Estate — Production Setup Guide
## Supabase Backend (No Firebase. No Cloudinary.)

---

## STEP 1 — Create Supabase Project
1. Go to https://supabase.com and sign in
2. Click **New Project**
3. Choose a name, set a strong database password, pick a region (closest to Nigeria: West EU or US East)
4. Wait ~2 minutes for provisioning

---

## STEP 2 — Run the Database Schema
1. In your Supabase dashboard → **SQL Editor**
2. Open the file `supabase_schema.sql` from this package
3. Paste the entire contents and click **Run**
4. You should see: *"Success. No rows returned."*

---

## STEP 3 — Create Storage Buckets
In Supabase Dashboard → **Storage** → **New Bucket**:

| Bucket Name | Public |
|---|---|
| `property-images` | ✅ ON |
| `property-videos` | ✅ ON |

Then for **each bucket**, go to **Policies** and add:
- **SELECT** → `true` (public reads)
- **INSERT** → `(auth.role() = 'authenticated')`
- **DELETE** → `(auth.role() = 'authenticated')`

---

## STEP 4 — Create the Admin Account in Supabase Auth
1. Supabase Dashboard → **Authentication** → **Users** → **Add User**
2. Email: `bakeroghenefejiro1@gmail.com`
3. Password: (your secure admin password)
4. Tick **"Auto Confirm User"**

---

## STEP 5 — Fill in Your .env File
Open `.env` and fill in your real values:

```env
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...your-anon-key...

PAYSTACK_PUBLIC_KEY=pk_live_xxxxxxxxxxxxxxxxxxxx
PAYSTACK_SECRET_KEY=sk_live_xxxxxxxxxxxxxxxxxxxx
PAYSTACK_CALLBACK_URL=https://maximusrealestate.ng/payment/callback

ADMIN_EMAIL=bakeroghenefejiro1@gmail.com
```

Get your Supabase URL and anon key from:
**Supabase Dashboard → Settings → API**

> ⚠️ For production, switch Paystack keys from `pk_test_` / `sk_test_` to `pk_live_` / `sk_live_`

---

## STEP 6 — Add .env to .gitignore
```
# .gitignore
.env
```

---

## STEP 7 — Copy Migrated Files Into Your Project

Replace every file in your Flutter project with the corresponding file from this package:

### New File (doesn't exist yet)
| File | Location in your project |
|---|---|
| `lib/config/app_config.dart` | `lib/config/app_config.dart` |
| `lib/services/supabase_storage_service.dart` | `lib/services/supabase_storage_service.dart` |

### Replace These Files
| File | Replaces |
|---|---|
| `pubspec.yaml` | `pubspec.yaml` |
| `lib/main.dart` | `lib/main.dart` |
| `lib/models/user_model.dart` | `lib/models/user_model.dart` |
| `lib/models/property_model.dart` | `lib/models/property_model.dart` |
| `lib/models/inspection_model.dart` | `lib/models/inspection_model.dart` |
| `lib/models/transaction_model.dart` | `lib/models/transaction_model.dart` |
| `lib/providers/auth_provider.dart` | `lib/providers/auth_provider.dart` |
| `lib/providers/admin_auth_provider.dart` | `lib/providers/admin_auth_provider.dart` |
| `lib/providers/property_provider.dart` | `lib/providers/property_provider.dart` |
| `lib/services/production_paystack_service.dart` | `lib/services/production_paystack_service.dart` |
| `lib/screens/favorites_screen.dart` | `lib/screens/favorites_screen.dart` |
| `lib/screens/profile_screen.dart` | `lib/screens/profile_screen.dart` |
| `lib/screens/property_details_screen.dart` | `lib/screens/property_details_screen.dart` |
| `lib/screens/inspection_booking_screen.dart` | `lib/screens/inspection_booking_screen.dart` |
| `lib/screens/admin/admin_add_property_screen.dart` | `lib/screens/admin/admin_add_property_screen.dart` |
| `lib/screens/admin/admin_inspections_screen.dart` | `lib/screens/admin/admin_inspections_screen.dart` |
| `lib/screens/admin/admin_users_screen.dart` | `lib/screens/admin/admin_users_screen.dart` |
| `lib/screens/admin/admin_manage_property_screen.dart` | `lib/screens/admin/admin_manage_property_screen.dart` |
| `lib/screens/admin/admin_commission_dashboard.dart` | `lib/screens/admin/admin_commission_dashboard.dart` |

### Files That Are Unchanged (no Firebase, already clean)
- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/signup_screen.dart`
- `lib/screens/seller_subscription_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/search_screen.dart`
- `lib/screens/main_screen.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/paystack_webview_screen.dart`
- `lib/screens/add_property_screen.dart`
- `lib/screens/admin/admin_dashboard_screen.dart`
- `lib/screens/admin/admin_analytics_screen.dart`
- `lib/widgets/property_card.dart`
- `lib/widgets/image_gallery_viewer.dart`
- `lib/utils/pdf_generator.dart`

---

## STEP 8 — Install Dependencies
```bash
flutter pub get
```

---

## STEP 9 — Delete All Firebase Files
Remove these files and folders from your project:
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
firestore.rules
firestore_indexes.json
storage.rules
```

Also remove from `android/app/build.gradle`:
```groovy
// Remove this line:
apply plugin: 'com.google.gms.google-services'
```

And from `android/build.gradle`:
```groovy
// Remove this line:
classpath 'com.google.gms:google-services:4.4.0'
```

---

## STEP 10 — Build & Test
```bash
flutter run
```

Test in order:
1. Sign up as a buyer
2. Sign up as a seller
3. Add a property (check images upload to Supabase Storage)
4. Browse properties
5. Book an inspection
6. Test contact unlock payment
7. Log in as admin (`bakeroghenefejiro1@gmail.com`)
8. Check admin dashboard loads correctly

---

## What Changed: Firebase → Supabase

| Feature | Firebase (before) | Supabase (after) |
|---|---|---|
| Authentication | Firebase Auth | Supabase Auth |
| Database | Firestore (NoSQL) | Supabase PostgreSQL |
| File Storage | Cloudinary | Supabase Storage |
| Realtime | Firestore StreamBuilder | Supabase Realtime Channels |
| Rules | `firestore.rules` | Row Level Security (SQL) |
| Config | Hardcoded in Dart | `.env` file |

## Key API Differences

```dart
// OLD (Firestore)
FirebaseFirestore.instance.collection('properties').get()
// NEW (Supabase)
Supabase.instance.client.from('properties').select()

// OLD (Firebase Auth)
FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: p)
// NEW (Supabase Auth)
Supabase.instance.client.auth.signInWithPassword(email: e, password: p)

// OLD (Cloud Storage / Cloudinary)
cloudinaryService.uploadImage(file)
// NEW (Supabase Storage)
supabaseStorageService.uploadImage(file)
```

## Data Model Changes (camelCase → snake_case)

Supabase uses SQL snake_case column names. The models handle this automatically via `fromSupabaseJson()` / `toSupabaseJson()`.

| Old Firestore field | New Supabase column |
|---|---|
| `ownerId` | `owner_id` |
| `isFeatured` | `is_featured` |
| `listingType` | `listing_type` |
| `inspectionFee` | `inspection_fee` |
| `buyPrice` | `buy_price` |
| `sellerPhone` | `seller_phone` |
| `createdAt` | `created_at` |
| `location.city` | `city` (flat column) |
