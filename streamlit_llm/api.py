from flask import Flask, request, jsonify
from flask_cors import CORS
from utils.llm_client import LMStudioClient
from utils.rag_utils import RAGManager
import threading

app = Flask(__name__)
CORS(app)

# Initialize clients
llm_client = LMStudioClient()
rag_manager = RAGManager()

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        messages = data.get('messages', [])
        temperature = data.get('temperature', 0.7)
        max_tokens = data.get('max_tokens', 1000)
        
        response = llm_client.chat_completion(
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        return jsonify({
            'response': response
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/upload_documents', methods=['POST'])
def upload_documents():
    try:
        data = request.json
        documents = data.get('documents', [])
        metadatas = data.get('metadatas', [])
        
        # Add documents to RAG system
        rag_manager.add_documents(documents, metadatas)
        
        return jsonify({'message': 'Documents uploaded successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/clear_documents', methods=['POST'])
def clear_documents():
    try:
        rag_manager.clear_database()
        return jsonify({'message': 'Documents cleared successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def run_flask():
    app.run(host='0.0.0.0', port=5000)  # Different port than Streamlit

if __name__ == '__main__':
    # Run Flask in a separate thread
    flask_thread = threading.Thread(target=run_flask)
    flask_thread.start()
    
    print("API Server running on http://0.0.0.0:5000")