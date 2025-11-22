 
# **Wallet Mitra 💰**

### *An effortless expense-management app with automatic Bank-SMS transaction tracking — built with Flutter.*

Wallet Mitra is a simple, clean, and lightweight expense manager built for people like me who **want to track expenses… but absolutely hate entering them manually**.
So instead of manually adding every chai, bus fare, and online payment — **Wallet Mitra auto-reads Bank SMS and adds transactions automatically.**

Lazy-friendly ✔️
Accurate ✔️
Effortless ✔️

---

## 🚀 **Features**

### ✅ **Automatic Expense Tracking (Bank SMS Parsing)**

Wallet Mitra securely reads incoming bank messages on-device and instantly logs your expenses and credits.

### 🎯 **Minimal & Intuitive UI**

A smooth Flutter UI showing:

* Total Balance
* Total Spent
* Monthly Transaction List
* Color-coded Income/Expense entries
* Search & Filters

### 📅 **Monthly Breakdown**

View all your expenses month-by-month with a clean scrollable selector.

### ➕ **Manual Add (If Needed 😄)**

Add cash expenses or any custom transaction manually.

### 🔐 **100% Offline**

All data lives on your device.
No servers. No analytics. No tracking.

---

## 🧠 **Why I Built This**

There are tons of expense apps — but none solved *my* problem:

> **I’m too lazy to manually enter transactions.**

Bank SMS already tells me everything…
So why not let the app do the heavy lifting?

Thus, Wallet Mitra was born — **automation over discipline**.

---

## 🛠️ **Tech Stack**

* **Flutter**
* **Dart**  
* **SMS Receiver Plugin**
* **Material Design UI**

---

## 📸 **Screenshots**
 <img width="1600" height="1600" alt="image" src="https://github.com/user-attachments/assets/4bac788a-96d2-42ca-be3d-9136a62f9311" />

---

## 🔧 **Setup Instructions**

1. Clone the repo:

   ```bash
   git clone https://github.com/your-username/wallet-mitra.git
   ```
2. Open the project in **Android Studio** or **VS Code**.
3. Run `flutter pub get`.
4. Add required SMS permissions in `AndroidManifest.xml`:

   ```xml
   <uses-permission android:name="android.permission.RECEIVE_SMS" />
   <uses-permission android:name="android.permission.READ_SMS" />
   ```
5. Run on a **real device** (SMS reading doesn't work on most emulators).
6. Start receiving automatic expense logs. 🎉

---

## 📜 **Permissions**

| Permission    | Why it's needed                                |
| ------------- | ---------------------------------------------- |
| `RECEIVE_SMS` | Detect bank messages instantly.                |
| `READ_SMS`    | Required by some devices to parse SMS content. |

> ⚠️ **All SMS reading is processed locally. No data ever leaves the device.**

---
 
## 🤝 **Contributing**

PRs are welcome!
If proposing a major change, please open an issue first.

---

## 💬 **Feedback**

Have ideas or feature suggestions?
Open an issue — I’d love to hear from you!
 
