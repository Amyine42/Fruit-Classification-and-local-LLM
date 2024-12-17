import json
from typing import Dict, List
import requests
from utils.rag_utils import RAGManager

class LMStudioClient:
    def __init__(self, base_url: str = "http://localhost:1234/v1"):
        self.base_url = base_url
        self.rag_manager = RAGManager()
        
    def chat_completion(self, messages: List[Dict[str, str]], 
                       temperature: float = 0.7,
                       max_tokens: int = 1000) -> str:
        try:
            # Get the latest user message
            latest_msg = messages[-1]['content'] if messages else ""
            
            # Retrieve relevant context
            context = self.rag_manager.get_relevant_context(latest_msg)
            
            # Construct augmented prompt
            augmented_messages = messages[:-1] + [{
                "role": "system",
                "content": f"Use the following relevant information to help answer the user's question:\n\n{context}\n\nIf the context is not relevant to the question, you can ignore it."
            }, messages[-1]]
            
            response = requests.post(
                f"{self.base_url}/chat/completions",
                json={
                    "messages": augmented_messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    "stream": False
                },
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
        except requests.exceptions.RequestException as e:
            return f"Error communicating with LM Studio: {str(e)}"
            
    def add_documents(self, documents: List[str], metadatas: List[Dict] = None):
        """Add documents to the RAG system"""
        self.rag_manager.add_documents(documents, metadatas)
        
    def clear_documents(self):
        """Clear all documents from the RAG system"""
        self.rag_manager.clear_database()