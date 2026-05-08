# ✈️ نظام حجز تذاكر الطيران
## Flutter + Firebase | University Project

---

## 📁 محتويات الملف المضغوط

```
flight_booking_system/
├── flight_client_app/      ← تطبيق العميل (Mobile)
├── flight_admin_web/       ← لوحة التحكم (Web)
├── flights_sample.xlsx     ← ملف Excel نموذجي
└── README.md
```

---

## ⚙️ المتطلبات

- Flutter SDK 3.x : https://flutter.dev/docs/get-started/install
- Android Studio أو VS Code
- حساب Google

تحقق:
```bash
flutter doctor
```

---

## 🔥 الخطوة 1: إعداد Firebase

1. افتح https://console.firebase.google.com
2. أنشئ مشروع باسم `flight-booking-app`
3. Authentication → Get started → فعّل Email/Password و Google
4. Firestore Database → Create database → Start in test mode

### Firestore Security Rules
اذهب إلى Firestore → Rules والصق هذا:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /flights/{flightId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /orders/{orderId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
  }
}
```
اضغط Publish.

---

## 🔗 الخطوة 2: ربط Firebase

```bash
dart pub global activate flutterfire_cli
```

```bash
cd flight_client_app
flutterfire configure --project=flight-booking-app
```
```bash
cd ../flight_admin_web
flutterfire configure --project=flight-booking-app
```

---

## 📱 الخطوة 3: تشغيل تطبيق العميل

```bash
cd flight_client_app
flutter pub get
flutter run
```

---

## 🌐 الخطوة 4: تشغيل لوحة التحكم

```bash
cd flight_admin_web
flutter pub get
flutter run -d chrome
```

بيانات الدخول:
```
البريد:      admin@flight.com
كلمة المرور: admin123
```

---

## 🔑 الخطوة 5: تفعيل Google Sign In على Android

```bash
cd flight_client_app/android
./gradlew signingReport
```
انسخ SHA-1 ثم:
Firebase Console → Project Settings → Your apps → Android App → Add fingerprint

---

## 📊 الخطوة 6: إضافة رحلات

يدوياً: من لوحة التحكم → إضافة رحلة

من Excel: استخدم flights_sample.xlsx
لوحة التحكم → استيراد Excel → اختر الملف
تنسيق التاريخ: dd/MM/yyyy مثال: 15/08/2025

---

## 🧪 الخطوة 7: اختبار كامل

1. موبايل: أنشئ حساباً جديداً
2. موبايل: أضف رحلة للسلة وأكّد الحجز
3. ويب: لوحة التحكم → الطلبات → قبول
4. موبايل: طلباتي → ستجد الحالة مقبول تلقائياً
5. ويب: الفواتير → حدد طلبات → اطبع PDF

---

## 📋 هيكل Firestore

```
users/{uid}     → name, email, phone, address
flights/{id}    → origin, destination, date, price, availableSeats
orders/{id}     → userId, flightId, origin, destination, flightDate, price, status, createdAt
```

---

## 🎓 نقاط المناقشة

| المفهوم | الشرح |
|---------|-------|
| StreamBuilder | يحدّث UI تلقائياً عند تغيير Firebase |
| Future/async-await | للعمليات غير المتزامنة |
| Firebase Auth | إدارة تسجيل الدخول |
| Cloud Firestore | قاعدة بيانات NoSQL سحابية |
| SharedPreferences | حفظ بيانات محلية بسيطة |
| WriteBatch | رفع عدة سجلات دفعة واحدة |
