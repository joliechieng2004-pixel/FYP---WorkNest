# WorkNest

### SME Workforce Management System with Biometric Integration

WorkNest is a full-stack mobile solution designed to streamline attendance tracking for Small and Medium Enterprises (SMEs). Built with **Flutter** and **Firebase**, it features real-time GPS-validated clock-in/out, automated reporting, and a scalable architecture for biometric verification.

## Key Features

### Employee Module

* **GPS-Validated Attendance:** Accurate clock-in/out restricted by geographical location.
* **Personal Timesheet:** Real-time view of personal work history, hours worked, and approval status.
* **Performance Metrics:** Automated calculation of attendance and punctuality rates.

### Manager Module

* **Approval Workflow:** Centralized dashboard to approve or reject employee attendance logs.
* **Department Filtering:** Efficiently manage specific teams using unique department codes.
* **Real-time Analytics:** Instant visibility into daily attendance and punctuality statistics.
* **Denormalized Reporting:** Optimized data fetching for fast, responsive list views.

## Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend/Database:** [Firebase Firestore](https://firebase.google.com/docs/firestore) (NoSQL)
* **Authentication:** Firebase Auth
* **Hardware Integration:** & Location (GPS)

## System Architecture

WorkNest utilizes a **NoSQL Denormalization Strategy** to optimize performance. By duplicating key data (like `workerName`) into the attendance documents, the system achieves:

* **Reduced Latency:** Eliminates the need for client-side joins between "Users" and "Attendances".
* **Lower Costs:** Minimizes Firestore read operations.
* **Scalability:** Ensures the Manager Dashboard remains fast as the log volume increases.

## Getting Started

### Prerequisites

* Flutter SDK (^3.0.0)
* A Firebase Project
* Android Studio / VS Code

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/worknest.git

```


2. **Install dependencies**
```bash
flutter pub get

```


3. **Configure Firebase**
* Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
* Enable **Email/Password Authentication** in the Firebase Console.
* Create a **Firestore Database** with `users` and `attendances` collections.


4. **Run the app**
```bash
flutter run

```


## 👨‍💻 Author

**Jolie Chieng Chiao Lie** *Final Year Software Engineering Student @ SEGi University* Expected Graduation: September 2026

---

**Would you like me to add a "Project Roadmap" section to the README to show the examiners what features you plan to add after graduation?**
