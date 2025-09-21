# filename: chatbot.py

from fastapi import APIRouter, Request, HTTPException, status
from fastapi.responses import JSONResponse, Response
import google.generativeai as genai
import os
import logging
import time
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Deque
from dotenv import load_dotenv
import threading
from collections import defaultdict, deque
from pydantic import BaseModel, Field
import re

# --- Pydantic Models for Request and Response validation ---
class ChatMessage(BaseModel):
    role: str
    content: str
    timestamp: str

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    session_id: str = "default"
    language: Optional[str] = "en-US" # <-- ADDED: To receive language hint

class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1)
    language: str = "en-US"

class ClearConversationRequest(BaseModel):
    session_id: str = "default"

# --- Create a Router instead of a full FastAPI app ---
router = APIRouter(
    tags=["Chatbot"],
)

# --- Logging ---
logger = logging.getLogger(__name__)

# --- RAG: Knowledge Base Loading (No changes here) ---
knowledge_base: List[Dict] = []
def load_knowledge_base():
    """Loads the knowledge base from the JSON file."""
    global knowledge_base
    try:
        kb_path = os.path.join(os.path.dirname(__file__), 'knowledge_base', 'disease_info.json')
        with open(kb_path, 'r', encoding='utf-8') as f:
            knowledge_base = json.load(f)
        logger.info(f"Successfully loaded knowledge base with {len(knowledge_base)} entries.")
    except Exception as e:
        logger.error(f"Knowledge base loading failed: {e}")
        knowledge_base = []

def retrieve_context(query: str) -> str:
    """Retrieves relevant context from the knowledge base based on the user's query."""
    if not knowledge_base:
        return "Knowledge base is not available."

    query_words = set(re.split(r'\s+', query.lower()))
    relevant_entries = []
    for category in knowledge_base:
        for item in category.get('items', []):
            searchable_text = ""
            if isinstance(item.get('name'), dict):
                searchable_text += item['name'].get('en', '') + " " + item['name'].get('ta', '')
            if isinstance(item.get('symptoms'), dict):
                searchable_text += " ".join(item['symptoms'].get('en', [])) + " " + " ".join(item['symptoms'].get('ta', []))
            
            if any(word in searchable_text.lower() for word in query_words):
                relevant_entries.append(json.dumps(item, ensure_ascii=False, indent=2))

    if not relevant_entries:
        return "No specific information found in the knowledge base for this query."
    
    return "\n---\n".join(relevant_entries[:3])


# --- Core Logic Classes (No major changes) ---
class ConversationManager:
    # --- No changes needed in this class ---
    def __init__(self):
        self.conversations: Dict[str, Dict] = {}
        self.message_counts: Dict[str, Deque] = defaultdict(lambda: deque())
        self.lock = threading.RLock()
    def get_conversation(self, session_id: str) -> List[Dict]:
        with self.lock:
            if session_id not in self.conversations:
                self.conversations[session_id] = {'messages': [], 'created_at': datetime.now(), 'last_activity': datetime.now()}
            return self.conversations[session_id]['messages']
    def add_message(self, session_id: str, role: str, content: str):
        with self.lock:
            conversation = self.get_conversation(session_id)
            conversation.append({'role': role, 'content': content, 'timestamp': datetime.now().isoformat()})
            self.conversations[session_id]['last_activity'] = datetime.now()
            if len(conversation) > 20:
                self.conversations[session_id]['messages'] = conversation[-20:]
    def is_rate_limited(self, session_id: str) -> bool:
        with self.lock:
            now = time.time()
            minute_ago = now - 60
            while (self.message_counts[session_id] and self.message_counts[session_id][0] < minute_ago):
                self.message_counts[session_id].popleft()
            if len(self.message_counts[session_id]) >= RATE_LIMIT_PER_MINUTE:
                return True
            self.message_counts[session_id].append(now)
            return False
    def cleanup_old_conversations(self):
        with self.lock:
            cutoff_time = datetime.now() - timedelta(seconds=CONVERSATION_TIMEOUT)
            expired_sessions = [sid for sid, data in self.conversations.items() if data['last_activity'] < cutoff_time]
            for session_id in expired_sessions:
                del self.conversations[session_id]
                if session_id in self.message_counts:
                    del self.message_counts[session_id]
            if expired_sessions:
                logger.info(f"Cleaned up {len(expired_sessions)} expired conversations")

conversation_manager = ConversationManager()

class GeminiAIHandler:
    def __init__(self):
        self.model = genai.GenerativeModel("gemini-1.5-flash")
        # Ensure you are using a model that supports TTS, like a preview model.
        # This model name might change. Check Google's documentation.
        self.tts_model = genai.GenerativeModel("gemini-1.5-flash") # Using flash for TTS prompt
        self.safety_settings = [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        ]
    
    # UPDATED to accept language
    def generate_response(self, message: str, conversation_history: List[Dict] = None, language: str = "en-US") -> Tuple[str, bool]:
        try:
            context = retrieve_context(message)
            
            history_str = "\n".join(
                [f"{'User' if msg['role'] == 'user' else 'Assistant'}: {msg['content']}" for msg in conversation_history[-6:]]
            )

            prompt = f"""
            You are an expert agricultural assistant for an e-commerce app.
            **Instructions:**
            1.  **Prioritize the Knowledge Base:** First, carefully analyze the "Retrieved Context from Knowledge Base" to answer the user's question. Base your answer strictly on this information if it's relevant.
            2.  **Fallback to General Knowledge:** If the retrieved context is not sufficient or doesn't contain the answer, then use your general knowledge to provide a helpful response.
            3.  **Language:** The user's preferred language is '{language}'. Please respond in this language. If the question itself is in a different language, prioritize responding in the language of the question.
            4.  **Be Concise:** Provide clear, direct, and helpful answers.
            ---
            **Retrieved Context from Knowledge Base:**
            {context}
            ---
            **Recent Conversation History:**
            {history_str}
            ---
            **User's Current Question:** "{message}"
            ---
            **Assistant's Answer:**
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config={"temperature": 0.7}
            )
            
            if response and response.candidates:
                reply = response.candidates[0].content.parts[0].text
                return reply.strip(), True
            else:
                return "I couldn't generate a response. Please try again.", False
            
        except Exception as e:
            logger.error(f"Error generating AI response: {str(e)}")
            return f"I encountered an error: {str(e)}", False

    # UPDATED to use language in prompt
    def text_to_speech(self, text: str, lang: str) -> Optional[bytes]:
        try:
            # Using a prompt-based approach for TTS with a general model
            # For direct TTS API, the method would be different.
            # This is a creative use of a multimodal model.
            tts_prompt = f"Read the following text aloud in a clear, friendly voice, in the language identified by the code '{lang}': {text}"
            
            response = self.tts_model.generate_content(
                tts_prompt,
                generation_config={"response_mime_type": "audio/wav"},
            )

            if response and response.candidates and response.candidates[0].content.parts:
                audio_part = response.candidates[0].content.parts[0]
                if audio_part.mime_type == "audio/wav":
                    return audio_part.data
            return None
        except Exception as e:
            logger.error(f"Error in text-to-speech generation: {e}")
            return None


ai_handler = GeminiAIHandler()

# --- Background Task & Startup (No changes) ---
def cleanup_worker():
    while True:
        time.sleep(300)
        try:
            conversation_manager.cleanup_old_conversations()
        except Exception as e:
            logger.error(f"Error in cleanup worker: {e}")

def start_chatbot_services():
    load_dotenv()
    API_KEY = os.getenv("GEMINI_API_KEY")
    if not API_KEY:
        raise ValueError("GEMINI_API_KEY is missing!")
    genai.configure(api_key=API_KEY)

    global MAX_MESSAGE_LENGTH, RATE_LIMIT_PER_MINUTE, CONVERSATION_TIMEOUT
    MAX_MESSAGE_LENGTH = int(os.getenv("MAX_MESSAGE_LENGTH", "5000"))
    RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", "10"))
    CONVERSATION_TIMEOUT = int(os.getenv("CONVERSATION_TIMEOUT", "1800"))

    load_knowledge_base()
    logger.info("Starting Chatbot Services...")
    cleanup_thread = threading.Thread(target=cleanup_worker, daemon=True)
    cleanup_thread.start()
    logger.info("Chatbot background cleanup thread started.")


# --- API Endpoints ---
@router.post("/chat")
async def chat(chat_request: ChatRequest):
    # ... (no changes to validation logic)
    message = chat_request.message.strip()
    session_id = chat_request.session_id
    language = chat_request.language # <-- EXTRACT language from request
    
    if len(message) > MAX_MESSAGE_LENGTH:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Message too long.")
    if conversation_manager.is_rate_limited(session_id):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=f"Rate limit exceeded.")
    
    conversation_history = conversation_manager.get_conversation(session_id)
    conversation_manager.add_message(session_id, "user", message)
    
    # PASS language to the handler
    reply, success = ai_handler.generate_response(message, conversation_history, language=language)
    
    if success:
        conversation_manager.add_message(session_id, "assistant", reply)
        return {"reply": reply, "session_id": session_id}
    else:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=reply)

# --- Other endpoints remain unchanged ---
@router.post("/text-to-speech")
async def text_to_speech(tts_request: TTSRequest):
    audio_data = ai_handler.text_to_speech(tts_request.text, tts_request.language)
    if audio_data:
        return Response(content=audio_data, media_type="audio/wav")
    else:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate audio")

@router.post("/conversation/clear")
def clear_conversation(clear_request: ClearConversationRequest):
    session_id = clear_request.session_id
    with conversation_manager.lock:
        if session_id in conversation_manager.conversations:
            del conversation_manager.conversations[session_id]
        if session_id in conversation_manager.message_counts:
            del conversation_manager.message_counts[session_id]
    logger.info(f"Conversation cleared for session: {session_id}")
    return {"message": "Conversation history cleared", "session_id": session_id}