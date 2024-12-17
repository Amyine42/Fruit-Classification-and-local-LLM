from typing import Dict, List

class ChatHistory:
    def __init__(self):
        self.messages: List[Dict[str, str]] = []
        
    def add_message(self, role: str, content: str):
        self.messages.append({"role": role, "content": content})
        
    def get_messages(self) -> List[Dict[str, str]]:
        return self.messages
        
    def clear_history(self):
        self.messages = []