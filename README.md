# **Wallet Mitra 💰**

### *An effortless expense-management app with automatic Bank-SMS transaction tracking.*

Wallet Mitra is a simple, clean, and lightweight Android app built to solve a very real problem:

👉 **We all want to track expenses, but nobody wants to manually add every single transaction.**
So Wallet Mitra does that part for you — automatically.

---

## 🚀 **Features**

### ✅ **Automatic Expense Tracking (Bank SMS Parsing)**

Wallet Mitra reads your bank SMS (securely on-device) and auto-adds income/expense transactions into your ledger.

### 🎯 **Minimal & Intuitive UI**

A simple interface showing:

* Total Balance
* Total Spent
* Monthly Expense List
* Search & Filter Support

### 📅 **Monthly Breakdown**

Scroll through months easily and check past transactions.

### ➕ **Manual Add (If You Still Want To 😄)**

Add custom transactions for cash or non-SMS expenses.

### 📲 **Fully Offline**

All data stays on your device. No servers, no cloud, no tracking.

---

## 🧠 **Why I Built This?**

There are hundreds of expense apps.
But *I’m too lazy to add each transaction manually*.
So I built Wallet Mitra with one goal:

> **If the bank already sends me an SMS for every transaction… why not let the app do the work?**

Automation > Discipline ✔️

---

## 🛠️ **Tech Stack**

* **Kotlin**
* **Jetpack Compose**
* **Room Database**
* **SMS Broadcast Receiver**
* **Material 3 UI**
* **MVVM Architecture**

---

## 📸 **Screenshots**

*(Images from `./screenshots/` or use the one you uploaded)*

![App Screenshot](/mnt/data/a2e11b05-ca55-422c-b89e-e3005e6103a0.png)

---

## 🔧 **Setup Instructions**

1. Clone the repo:

   ```bash
   git clone https://github.com/your-username/wallet-mitra.git
   ```
2. Open the project in **Android Studio**.
3. Enable **SMS permission** in the manifest.
4. Run on a real device (SMS reading doesn't work on emulator).
5. You're good to go!

---

## 📜 **Permissions**

| Permission    | Why it's needed                                  |
| ------------- | ------------------------------------------------ |
| `RECEIVE_SMS` | To auto-detect bank transactions from SMS.       |
| `READ_SMS`    | Required by some OEMs to read incoming messages. |

> 📌 *All SMS parsing happens locally. No data leaves your device.*

---

## 🗺️ **Roadmap**

* [ ] Export to CSV
* [ ] Category-wise insights
* [ ] Dark mode
* [ ] Budget planner
* [ ] Backup/Restore

---

## 🤝 **Contributing**

Pull requests are welcome!
If you're suggesting major changes, open an issue first to discuss what you’d like to modify.

---

## 💬 **Feedback**

Got ideas? Suggestions? Found a bug?
Feel free to open an issue or ping me on LinkedIn.

---

## ⭐ **Support**

If you find this helpful, consider giving the repo a **⭐** — it helps a lot!

 