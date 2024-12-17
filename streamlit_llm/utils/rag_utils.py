from langchain.vectorstores import FAISS
from langchain.embeddings import HuggingFaceEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from typing import List, Dict
import os
import pickle

class RAGManager:
    def __init__(self, index_path: str = "faiss_index"):
        self.index_path = index_path
        self.embeddings = HuggingFaceEmbeddings(
            model_name="all-MiniLM-L6-v2",
            model_kwargs={'device': 'cpu'}
        )
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=500,
            chunk_overlap=50
        )
        
        # Initialize or load the vector store
        if os.path.exists(f"{index_path}.pkl"):
            with open(f"{index_path}.pkl", "rb") as f:
                self.vector_store = pickle.load(f)
        else:
            self.vector_store = None
    
    def add_documents(self, documents: List[str], metadatas: List[Dict] = None):
        """Add documents to the vector store"""
        # Split documents into chunks
        splits = self.text_splitter.create_documents(documents, metadatas=metadatas)
        
        # Create new vector store or add to existing one
        if self.vector_store is None:
            self.vector_store = FAISS.from_documents(splits, self.embeddings)
        else:
            self.vector_store.add_documents(splits)
        
        # Save the index
        with open(f"{self.index_path}.pkl", "wb") as f:
            pickle.dump(self.vector_store, f)
    
    def get_relevant_context(self, query: str, k: int = 3) -> str:
        """Retrieve relevant document chunks for a query"""
        if self.vector_store is None:
            return ""
            
        # Search for similar documents
        docs = self.vector_store.similarity_search(query, k=k)
        
        # Combine the relevant chunks
        context = "\n\n".join([doc.page_content for doc in docs])
        return context
    
    def clear_database(self):
        """Clear all documents from the vector store"""
        self.vector_store = None
        if os.path.exists(f"{self.index_path}.pkl"):
            os.remove(f"{self.index_path}.pkl")