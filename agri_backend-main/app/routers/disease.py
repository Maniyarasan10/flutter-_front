# filename: disease_detector.py

import os
import io
import json
import logging
import uvicorn
from fastapi import FastAPI, APIRouter, File, UploadFile, HTTPException
from PIL import Image
from dotenv import load_dotenv
import google.generativeai as genai

# --- Basic Logging Configuration ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- Load Environment Variables ---
# This safely loads your secret API key from a .env file.
load_dotenv()

# --- Create a Router for Disease Detection Endpoints ---
# Using a router keeps the code organized and modular.
router = APIRouter(
    tags=["Disease Detector"],
)

# --- Gemini API Configuration ---
API_KEY = os.getenv("GOOGLE_API_KEY")

if not API_KEY:
    logger.critical("❌ FATAL ERROR: GOOGLE_API_KEY not found in .env file. The application cannot start.")
    model = None
else:
    try:
        genai.configure(api_key=API_KEY)
        # Use a model that supports vision (image) inputs.
        model = genai.GenerativeModel('gemini-1.5-flash-latest')
        logger.info("✅ Gemini 1.5 Flash model loaded successfully.")
    except Exception as e:
        logger.critical(f"❌ Error configuring Gemini API: {e}")
        model = None

# --- System Prompt for the AI Model ---
# This prompt is crucial. It forces the AI to respond in a structured JSON format
# that perfectly matches the DiseaseResult model in your Flutter app.
system_prompt = """
You are an expert botanist and plant pathologist. Your task is to analyze an image of a plant leaf and identify any diseases.

Your response MUST be in a valid JSON format with the following exact structure:
{
  "disease_name": "Name of the disease or 'Healthy'",
  "precautions": [
    "A concise, actionable precaution 1.",
    "A concise, actionable precaution 2."
  ],
  "remedies": [
    "A concise, actionable remedy 1.",
    "A concise, actionable remedy 2."
  ],
  "medicines": [
    {
      "name": "Chemical or Organic Medicine Name 1",
      "mixing_ratio": "e.g., '10ml per 1 liter of water'"
    }
  ]
}

- If the plant is healthy, set "disease_name" to "Healthy" and provide general care tips in the other fields.
- If the image is not a plant or is unclear, set "disease_name" to "Identification Failed" and leave other fields as empty arrays.
- Do not include any text, explanations, or markdown formatting like ```json before or after the JSON object.
"""

# --- API Endpoint Definition ---
@router.post("/predict")
async def predict_disease(file: UploadFile = File(...)):
    """
    Receives an image file, sends it to the Gemini model for analysis,
    and returns structured disease information in JSON format.
    """
 # --- ADD THESE TWO LINES FOR DEBUGGING ---
    print(f"Received file: '{file.filename}' with content type: '{file.content_type}'")
    # -----------------------------------------


    if not model:
        raise HTTPException(status_code=503, detail="AI Model is not available. Check server configuration.")

    # Validate that the uploaded file is an image.
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload an image.")

    try:
        # Read the image file into memory.
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))

        # --- Send the prompt and image to the Gemini API ---
        logger.info("Sending image to Gemini for analysis...")
        response = model.generate_content([system_prompt, image])
        
        # Clean the response to ensure it's a valid JSON string.
        # This removes potential markdown formatting from the AI's output.
        json_text = response.text.strip().replace("```json", "").replace("```", "")
        
        logger.info(f"Received response from Gemini: {json_text}")
        
        # Parse the cleaned text into a Python dictionary.
        result = json.loads(json_text)
        
        # FastAPI automatically converts the dictionary to a JSON response.
        return result

    except json.JSONDecodeError:
        logger.error("Failed to decode JSON from Gemini response.")
        raise HTTPException(status_code=500, detail="Error parsing the AI's response.")
    except Exception as e:
        logger.error(f"An unexpected error occurred during prediction: {e}")
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")

# --- Main FastAPI Application ---
# This creates the main app instance and includes the disease router.
app = FastAPI(
    title="Agricultural AI Assistant API",
    description="Provides endpoints for plant disease detection and a support chatbot.",
    version="1.0.0",
)

@app.get("/", tags=["Root"])
def read_root():
    return {"status": "API is running successfully!"}

# Include the /disease/predict endpoint into the main application.
app.include_router(router)


# --- Run the application directly with Uvicorn ---
if __name__ == "__main__":
    logger.info("Starting FastAPI server...")
    uvicorn.run("disease_detector:app", host="0.0.0.0", port=8000, reload=True)