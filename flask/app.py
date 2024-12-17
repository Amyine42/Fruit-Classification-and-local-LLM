from flask import Flask, request, render_template, jsonify
import numpy as np
import tensorflow as tf
from pathlib import Path
from PIL import Image
from typing import Optional, Tuple, List
import os

app = Flask(__name__)

class ImageProcessor:
    VALID_EXTENSIONS = {'.jpg', '.jpeg', '.png'}
    IMAGE_SIZE = (32, 32)
    LABELS = [
        "Apple", "Banana", "avocado", "cherry", "kiwi",
        "mango", "orange", "pinenapple", "strawberries", "watermelon"
    ]
    
    def __init__(self):
         # Obtenir le chemin absolu du dossier du script
        self.base_dir = Path(os.path.dirname(os.path.abspath(__file__)))
        self.model = self._initialize_model()
        self.upload_dir = self.base_dir / 'static' / 'images'
        self.upload_dir.mkdir(parents=True, exist_ok=True)

    def _initialize_model(self) -> Optional[tf.keras.Model]:
        try:
            # Utiliser le chemin absolu pour le modèle
            model_path = self.base_dir.parent / 'assets' / 'fruitscnn10.h5'
            print(f"Trying to load model from: {model_path}")  # Debug print
            return tf.keras.models.load_model(str(model_path))
        except Exception as e:
            print(f"Model initialization error: {e}")
            return None

    def process_image(self, image_path: str) -> np.ndarray:
        with Image.open(image_path) as img:
            resized = img.resize(self.IMAGE_SIZE)
            return np.expand_dims(np.array(resized), axis=0)

    def predict(self, image: np.ndarray) -> Tuple[str, float]:
        raw_predictions = self.model.predict(image)
        probabilities = tf.nn.softmax(raw_predictions).numpy()
        predicted_idx = np.argmax(probabilities[0])
        return self.LABELS[predicted_idx], float(probabilities[0][predicted_idx])

    def validate_file(self, filename: str) -> bool:
        return Path(filename).suffix.lower() in self.VALID_EXTENSIONS

processor = ImageProcessor()

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/predict', methods=['POST'])
def predict():
    if 'file' not in request.files:
        return jsonify({"error": "Missing file"}), 400

    file = request.files['file']
    if not file.filename:
        return jsonify({"error": "No file selected"}), 400

    if not processor.validate_file(file.filename):
        return jsonify({"error": "Invalid file format"}), 400

    save_path = processor.upload_dir / file.filename
    file.save(save_path)
    
    processed_image = processor.process_image(str(save_path))
    prediction, confidence = processor.predict(processed_image)

    return render_template('index.html',
                         prediction=prediction,
                         probability=confidence,
                         image_filename=file.filename)

if __name__ == '__main__':
    app.run(port=8080, debug=True, use_reloader=False)