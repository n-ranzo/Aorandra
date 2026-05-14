# VideoApp

تطبيق فيديو قصير مثل TikTok وInstagram Reels، مبني بـ Flutter + Supabase.

## الميزات
- فيد فيديوهات عمودي (TikTok style)
- تسجيل دخول وإنشاء حساب
- رفع فيديوهات من الاستوديو
- لايكات مع تحديث فوري
- تعليقات
- بروفايل شخصي مع شبكة فيديوهات

## خطوات التشغيل

### 1. Supabase Setup
1. اذهب إلى supabase.com وأنشئ مشروعاً جديداً
2. في **SQL Editor**، الصق محتوى ملف `supabase_schema.sql` وشغّله
3. من **Settings > API** خذ `Project URL` و`anon key`

### 2. ضع بيانات Supabase
افتح `lib/core/supabase_config.dart` وضع بياناتك:
```dart
const supabaseUrl = 'https://xxxx.supabase.co';
const supabaseAnonKey = 'eyJhbGci...';
```

### 3. تشغيل التطبيق
```bash
cd VideoApp
flutter pub get
flutter run
```
