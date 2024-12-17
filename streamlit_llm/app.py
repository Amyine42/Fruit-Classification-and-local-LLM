import streamlit as st
from utils.llm_client import LMStudioClient
from utils.chat_history import ChatHistory

# Initialize session state for chat history
if "chat_history" not in st.session_state:
    st.session_state.chat_history = ChatHistory()

# Initialize LM Studio client
llm_client = LMStudioClient()

st.title("🤖 LM Studio Chat Interface")

# Settings sidebar
with st.sidebar:
    st.header("Settings")
    temperature = st.slider("Temperature", 0.0, 1.0, 0.7, 0.1)
    max_tokens = st.slider("Max Tokens", 100, 2000, 1000, 100)
    
    st.header("Document Upload")
    uploaded_files = st.file_uploader(
        "Upload documents for RAG", 
        accept_multiple_files=True,
        type=['txt', 'pdf']
    )
    
    if uploaded_files:
        if st.button("Process Documents"):
            documents = []
            metadatas = []
            
            for file in uploaded_files:
                # Read the file content
                content = file.read().decode()
                documents.append(content)
                metadatas.append({"source": file.name})
            
            llm_client.add_documents(documents, metadatas)
            st.success("Documents processed and added to RAG system!")
    
    if st.button("Clear Documents"):
        llm_client.clear_documents()
        st.success("All documents cleared from RAG system!")
    
    if st.button("Clear Chat History"):
        st.session_state.chat_history.clear_history()
        st.experimental_rerun()


# Chat interface
for message in st.session_state.chat_history.get_messages():
    role_icon = "🧑" if message["role"] == "user" else "🤖"
    with st.chat_message(message["role"], avatar=role_icon):
        st.write(message["content"])

# Chat input
if prompt := st.chat_input("What would you like to discuss?"):
    # Add user message to chat history
    st.session_state.chat_history.add_message("user", prompt)
    
    # Display user message
    with st.chat_message("user", avatar="🧑"):
        st.write(prompt)
    
    # Get response from LM Studio
    with st.chat_message("assistant", avatar="🤖"):
        with st.spinner("Thinking..."):
            response = llm_client.chat_completion(
                st.session_state.chat_history.get_messages(),
                temperature=temperature,
                max_tokens=max_tokens
            )
            st.write(response)
            
    # Add assistant response to chat history
    st.session_state.chat_history.add_message("assistant", response)

# import streamlit as st
# from transformers import pipeline, AutoTokenizer, AutoModelForCausalLM

# # Load the model and tokenizer
# @st.cache_resource
# def load_model_and_tokenizer():
#     """Load the Hugging Face model and tokenizer."""
#     model_name = "meta-llama/Llama-3.2-1B"  # Replace with the desired model name
#     tokenizer = AutoTokenizer.from_pretrained(model_name)
#     model = AutoModelForCausalLM.from_pretrained(model_name)
#     return pipeline("text-generation", model=model, tokenizer=tokenizer)

# # Streamlit app UI
# def main():
#     st.title("LLaMA Model Deployment with Streamlit")
#     st.subheader("Interact with the LLaMA model using Hugging Face Transformers")

#     # Input text box
#     user_input = st.text_area("Enter your prompt:", height=200)

#     # Generate response
#     if st.button("Generate Response"):
#         if user_input.strip():
#             with st.spinner("Generating response..."):
#                 text_generator = load_model_and_tokenizer()
#                 response = text_generator(user_input, max_length=200, num_return_sequences=1)
#                 st.success("Response:")
#                 st.write(response[0]["generated_text"].strip())
#         else:
#             st.warning("Please enter a prompt before generating a response!")

# # Entry point
# if __name__ == "__main__":
#     main()