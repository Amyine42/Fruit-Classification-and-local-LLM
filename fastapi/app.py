from fastapi import FastAPI, File, UploadFile
import tensorflow as tf
import numpy as np
from PIL import Image
from io import BytesIO
import os

app = FastAPI()

class FruitClassifier:
    def __init__(self):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        model_path = os.path.join(base_dir, 'assets', 'fruitscnn10.h5')
        self.model = tf.keras.models.load_model(model_path)
        self.labels = ["Apple", "Banana", "avocado", "cherry", "kiwi", 
                      "mango", "orange", "pinenapple", "strawberries", "watermelon"]
        self.img_size = (32, 32)
        
    async def predict(self, image_data: bytes) -> dict:
        image = Image.open(BytesIO(image_data))
        image = image.resize(self.img_size)
        image = np.expand_dims(np.array(image), axis=0)
        
        prediction = self.model.predict(image)
        probabilities = tf.nn.softmax(prediction).numpy()
        
        index = np.argmax(probabilities[0])
        return {
            "prediction": self.labels[index],
            "confidence": float(probabilities[0][index])
        }

classifier = FruitClassifier()

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    contents = await file.read()
    result = await classifier.predict(contents)
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)