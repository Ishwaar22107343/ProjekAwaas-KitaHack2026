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

[https://drive.google.com/file/d/1rD8U1OzvAKSu9Ypd5xlAKBvR50PxB5QK/view?usp=drivesdk]

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

### 🚧 Challenges Faced

Developing "Projek Awaas" presented several technical hurdles, primarily related to securing efficient data flow and authentication between mobile and cloud services:

**1. Direct Google Cloud Storage (GCS) Integration & Authentication:**
- Initially, we explored uploading images directly to GCS and importing them from there for AI prompting. However, integrating GCS directly with the mobile app proved complex due to the authentication requirements. Our use of anonymous Firebase authentication for the mobile app did not seamlessly translate to GCS, making direct secure access difficult for a prototype. Firebase Storage offered a more streamlined and efficient solution for image uploads within our mobile ecosystem.

**2. Cross-Service Authentication (App to Gemini via Firebase):**
- Another challenge arose when the application manually attempted to call the Gemini API directly from the app, expecting Gemini to then import the picture from Firebase Storage. This setup encountered authentication issues, as Firebase's security mechanisms prevented direct unauthorized access from Gemini services to user-uploaded content. The challenge was to establish a secure and authenticated channel for the image to reach the AI model.

**Solution:**
- The breakthrough came with implementing an event-driven architecture leveraging Google Cloud Functions. By having the Flutter app upload the image to Firebase Storage, we could trigger a Cloud Function (process_flood_image) upon new file uploads. This intermediary Cloud Function, running within the Google Cloud ecosystem, inherently possesses the necessary permissions to access Firebase Storage and invoke Vertex AI (Gemini). This setup resolved the authentication barrier, allowing seamless communication between Firebase, Google Cloud Functions, and Vertex AI, effectively bypassing the security complexities of direct client-to-cloud AI interaction while maintaining the serverless and scalable nature of the project.

---

### Roadmap and Future Enhancements

"Projek Awaas" currently provides real-time flood analysis for static images. Our vision for the future includes expanding its capabilities significantly to offer more dynamic and comprehensive flood assessment and community-driven data collection:

**1. Video Analysis for Advanced Flood Assessment:**
- Enhanced AI Models: Future iterations will incorporate video analysis capabilities. Instead of just static images, the AI model will be able to process video streams of flooded roads.
- Dynamic Data Points: This will allow for the assessment of dynamic factors such as water flowing speed, balance (e.g., how steady a person or object is in the water), and even the sound of the water stream. These additional data points will significantly improve the AI's ability to gauge the true risk and provide more accurate "PROCEED" or "TURN BACK" decisions.
- Contextual Understanding: Analyzing movement and sound will give the AI a richer contextual understanding of the flood situation, beyond what a single image can convey.

**2. Public, Real-Time, Street-Level Flood Database:**
- User-Contributed Data: We plan to implement a feature where every user-submitted photo or video, along with its AI analysis result ("PROCEED" or "TURN BACK"), will be anonymized and saved to a public database, tagged with its precise location.
- Hyper-Local Accuracy: This database will provide real-time, street-level accuracy of flood conditions, offering a significant improvement over existing regional flood maps. Users won't need to physically be present to assess a location; they can check the app for the latest community-reported status.
- Dynamic Updates: The information for a particular location will be continuously updated by new user submissions, ensuring the data remains current and relevant.
- Automatic Refresh: The system will intelligently refresh or mark data as "cleared" once floodwaters at a specific location are observed to recede, providing an up-to-date picture of accessible roads.

---

### Security note: 

- The firebase_options.dart file in this repository contains placeholder API keys. In a real-world public scenario, these should be secured and managed via environment variables or a more secure configuration method. For this hackathon submission, they are included for ease of evaluation.

---
