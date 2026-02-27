# Projek Awaas - KitaHack 2026 Submission

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?style=for-the-badge&logo=firebase)](https://firebase.google.com)
[![Google Cloud](https://img.shields.io/badge/Platform-Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud)](https://cloud.google.com)
[![Vertex AI](https://img.shields.io/badge/AI-Vertex_AI-4285F4?style=for-the-badge&logo=google-cloud)](https://cloud.google.com/vertex-ai)

**Projek Awaas** is a mobile application developed for the KitaHack 2026 hackathon. It provides a crucial safety service by using AI to analyze photos of flooded roads and advise a user whether it is safe to **"PROCEED"** or if they must **"TURN BACK"**.

This project directly addresses the challenges of climate change and urban safety, aligning with **UN Sustainable Development Goals 3 (Good Health & Well-being), 11 (Sustainable Cities & Communities), and 13 (Climate Action)**.

---

### Problem Statement

> How can we develop innovative, scalable, and sustainable AI-powered solutions that address real-world problems aligned with one or more SDGs using Google's technology stack, moving from theoretical knowledge to deployable applications that create measurable community impact?

---

### :movie_camera: 5-Minute Demo Video

[Link to Your 5-Minute Project Demo Video Here]

---

### ✨ Key Features

*   **Real-Time Flood Analysis**: Uses the phone's camera to capture current road conditions.
*   **AI-Powered Decisions**: Sends the image to a cloud backend where a Gemini AI model assesses the risk.
*   **Simple, Clear Instructions**: Returns an unambiguous "PROCEED" or "TURN BACK" command.
*   **Contextual Reasoning**: Provides a simple reason for the AI's decision (e.g., "Water is deep enough to stall the engine").
*   **Serverless & Scalable**: Built entirely on a modern, event-driven Google Cloud architecture.

---

### 🏗️ Deployed Architecture

The project follows a fully serverless, event-driven architecture.

1.  **Flutter App**: The user captures a photo.
2.  **Firestore (Create)**: The app creates a document in the `analysis_jobs` collection with `status: "processing"`. The app begins listening to this document for changes.
3.  **Firebase Storage**: The app uploads the photo to Cloud Storage, named with the `jobId`.
4.  **Cloud Function Trigger**: The image upload triggers the `process_flood_image` Cloud Function.
5.  **Vertex AI Analysis**: The function sends the image and a detailed prompt to the Gemini model for analysis.
6.  **Firestore (Update)**: The function receives the JSON result from Gemini and updates the original Firestore document with `status: "completed"` and the AI's decision.
7.  **Flutter App (Update)**: The app's listener receives the update and instantly displays the result to the user.

---

### 🛠️ Technology Stack

*   **Frontend**: Flutter, Dart
*   **Backend**: Google Cloud Functions (Python 3.12)
*   **AI Model**: Vertex AI with `gemini-2.5-flash`
*   **Database**: Cloud Firestore
*   **Storage**: Firebase Storage
*   **Authentication**: Firebase Authentication (Anonymous)

---

### 📂 Project Structure

This repository is organized into two main parts to reflect the separation of frontend and backend code.

```text
/
├── flood_app/ # Contains the complete Flutter mobile application source code.
│ ├── lib/
│ ├── android/
│ ├── pubspec.yaml
│ └── ...
│
├── cloud_function/ # Contains the backend Google Cloud Function code.
│ ├── main.py
│ └── requirements.txt
│
└── README.md # This file.
```

---

### 🚀 Setup and Installation

**Prerequisites:**
*   Flutter SDK (version >=3.0.0)
*   Google Cloud SDK (for deploying the function)
*   Firebase CLI

#### 1. Frontend (Flutter App)

The app is configured via FlutterFire and should work out-of-the-box if the Firebase project is set up.

```bash
# Navigate to the app directory
cd flood_app

# Install dependencies
flutter pub get

# Run the app on a connected device or emulator
flutter run
```
#### 2. Backend (Cloud Function)

The function process_flood_image is triggered by file uploads to the Firebase Storage bucket.

**IAM Permissions Required for the Function's Service Account:**
*   Vertex AI User: To call the Gemini model.
*   Cloud Datastore User: To update Firestore.
*   Storage Object Viewer: To read the image from the bucket.

**Deployment:**

To deploy the function, navigate to the cloud_function directory and use the gcloud CLI.

```bash
cd cloud_function

gcloud functions deploy process_flood_image \
--gen2 \
--runtime=python312 \
--region=<YOUR_FUNCTION_REGION> \
--source=. \
--entry-point=analyzeimageonupload \
--trigger-event-filters="type=google.storage.object.finalize" \
--trigger-event-filters="bucket=<YOUR_STORAGE_BUCKET_NAME>"
```

---

- Security note: The firebase_options.dart file in this repository contains placeholder API keys. In a real-world public scenario, these should be secured and managed via environment variables or a more secure configuration method. For this hackathon submission, they are included for ease of evaluation.
