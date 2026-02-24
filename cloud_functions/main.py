import functions_framework
import os
import json
from firebase_admin import initialize_app, firestore, _apps

import vertexai
from vertexai.generative_models import GenerativeModel, Part, GenerationConfig

# --- INITIALIZATION ---
PROJECT_ID = os.environ.get("GCP_PROJECT")
LOCATION = os.environ.get("FUNCTION_REGION")
vertexai.init(project=PROJECT_ID, location=LOCATION)

# --- CLOUD FUNCTION ---
@functions_framework.cloud_event
def analyzeimageonupload(cloud_event):
    if not _apps:
        initialize_app()

    data = cloud_event.data

    # --- Event Parsing ---
    try:
        bucket_name = data['bucket']
        file_path = data['name']
    except (KeyError, TypeError):
        print("Using complex event parsing.")
        try:
            bucket_name = data['resource']['labels']['bucket_name']
            full_resource_name = data['protoPayload']['resourceName']
            file_path = full_resource_name.split('/objects/')[1]
        except Exception as e:
            print(f"FATAL: Could not parse event data. Error: {e}")
            return
            
    print(f"File uploaded: {file_path} in bucket {bucket_name}")

    if not file_path.startswith("uploads/"):
        print(f"Ignoring non-app file: {file_path}")
        return

    # --- Job and Firestore Setup ---
    try:
        job_id = os.path.splitext(os.path.basename(file_path))[0]
        print(f"Extracted Job ID: {job_id}")
    except IndexError:
        print(f"Could not extract Job ID from filename: {file_path}")
        return
        
    db = firestore.client()
    job_ref = db.collection("analysis_jobs").document(job_id)

    doc = job_ref.get()
    if not doc.exists:
        print(f"Document {job_id} not found. Ignoring.")
        return

    # --- Vertex AI Analysis ---
    try:
        # --- ENGINEERED SYSTEM PROMPT ---
        system_prompt = """
        You are an AI safety assistant for a flood analysis app. Your goal is to determine if conditions are safe.
        You MUST respond with ONLY a valid, raw JSON object with three keys: "decision", "reason", and "confidence".

        Follow this two-step process:

        **STEP 1: Determine the Point of View (POV).**
        - Look for signs the photo was taken from inside a vehicle (dashboard, steering wheel, windscreen, side mirror).
        - If signs of a vehicle interior are present, the POV is 'DRIVER'.
        - Otherwise, assume the POV is 'PEDESTRIAN'.

        **STEP 2: Apply safety rules based on the determined POV.**

	--- DETERMINING WATER DEPTH AND CURRENT ---
	1.  **Water Depth:** Determine water depth based on surrounding objects like sidewalk, street lamp, vehicles, trees and surrounding humans.
	2.  **Current:** Determine water current based on observing the speed and direction of surface movement and interaction with surrounding objects from a safe, elevated, or distant position. Key indicators include the movement of debris, water interaction with structures, and surface characteristics.
        
	--- IF POV IS 'DRIVER' ---
        1.  **Current First:** If you see a strong, fast-flowing current (waves, splashes, debris moving quickly), the decision is "TURN_BACK". Reason: "Fast current detected. High risk of the vehicle being swept away." Confidence should be high.
        2.  **Depth Second:** If the water is calm:
            - Water below the car's chassis/tires: "PROCEED". Reason: "Water level is low and appears safe for a vehicle to cross."
            - Water reaches the middle of the wheels or bottom of the car doors: "TURN_BACK". Reason: "Water is deep enough to stall the engine and cause loss of control."
            - Water is clearly above the middle of the doors: "TURN_BACK". Reason: "Extreme flood depth. Do not attempt to cross."

        --- IF POV IS 'PEDESTRIAN' ---
        1.  **Current First:** If you see any significant strong current, the decision is "TURN_BACK". Reason: "Flowing water is dangerous to walk through and can easily cause a fall." Confidence should be high.
        2.  **Depth Second:** 
	If the water is perfectly still:
            - Water is at or below waist-level: "PROCEED". Reason: "Water is below waist level. Proceed with caution and watch your step."
            - Water is above wasit-level: "TURN_BACK". Reason: "Water is too deep to walk in safely. Hidden obstacles or uneven ground pose a significant risk."
	If the water flowing slowly (no strong current):
	    - Water is at or below knee-level: "PROCEED". Reason: "Water is shallow and weak current. Procced with caution and watch your step."
	    - Water above knee-level: "TURN_BACK". Reason: "Water is deep with weal current. Stabiity challenged in flowing water."  

        --- FALLBACK RULES (Apply to both POVs) ---
        - If you cannot reliably assess conditions (e.g., bad lighting, blurry, no reference points), err on the side of caution. Decision: "TURN_BACK", Reason: "Unable to reliably assess flood risk from the image."
        - If the image is blank, invalid, use this exact response:
          {"decision": "TURN_BACK", "reason": "Image is blank, invalid, or does not show a relevant scene.", "confidence": 1.0}
        """

        # --- CONFIGURE GENERATION PARAMETERS ---
        generation_config = GenerationConfig(
            temperature=0.0,
            response_mime_type="application/json"
        )
        
        # --- INITIALIZE THE MODEL WITH SYSTEM PROMPT ---
        model = GenerativeModel(
            "gemini-2.5-flash",
            system_instruction=[system_prompt],
            generation_config=generation_config
        )
        
        gcs_uri = f"gs://{bucket_name}/{file_path}"
        image_part = Part.from_uri(gcs_uri, mime_type="image/jpeg")
        
        # User prompt
        prompt_parts = [
            image_part,
            "Analyze the attached image based on your instructions."
        ]
        
        print(f"Sending request to Vertex AI for job {job_id}")
        response = model.generate_content(prompt_parts)
        
        # The model is now configured to output raw JSON directly
        result_json = response.candidates[0].content.parts[0].text
        
        print(f"Vertex AI response for job {job_id}: {result_json}")
        
        # --- Firestore Update ---
        job_ref.update({
            "status": "completed",
            "result": json.loads(result_json), # Parse the JSON string into a map
            "processedAt": firestore.SERVER_TIMESTAMP
        })
        print(f"Successfully processed and updated job {job_id}.")

    except Exception as e:
        print(f"An error occurred for job {job_id}: {e}")
        job_ref.update({
            "status": "failed",
            "error": str(e)
        })