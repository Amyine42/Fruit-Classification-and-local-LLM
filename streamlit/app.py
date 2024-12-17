import streamlit as st
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import os
from pathlib import Path

class FruitClassifier:
    def __init__(self):
        # Obtenir le chemin absolu du dossier courant
        model_path = "D:\\Lab_flutter\\elayoubi_app\\assets\\fruitscnn10.h5"
        self.model = tf.keras.models.load_model(str(model_path))
        self.labels = ["Apple", "Banana", "avocado", "cherry", "kiwi", 
                      "mango", "orange", "pinenapple", "strawberries", "watermelon"]
        self.img_size = (32, 32)
        
    def predict(self, image):
        img_array = np.array(image.resize(self.img_size))
        img_array = np.expand_dims(img_array, axis=0)
        
        prediction = self.model.predict(img_array)
        probabilities = tf.nn.softmax(prediction).numpy()
        
        return {
            self.labels[i]: float(probabilities[0][i]) 
            for i in range(len(self.labels))
        }

def main():
    st.title("Fruit Classifier")
    st.write("Upload an image of a fruit to classify it!")

    classifier = FruitClassifier()
    uploaded_file = st.file_uploader("Choose an image...", type=["jpg", "jpeg", "png"])

    if uploaded_file:
        image = Image.open(uploaded_file)
        st.image(image, caption="Uploaded Image", use_column_width=True)        
        with st.spinner('Classifying...'):
            predictions = classifier.predict(image)
            
        st.subheader("Predictions:")
        for fruit, confidence in sorted(predictions.items(), key=lambda x: x[1], reverse=True):
            st.write(f"{fruit}: {confidence*100:.2f}%")

if __name__ == "__main__":
    main()