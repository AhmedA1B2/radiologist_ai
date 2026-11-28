Place the local Keras specialist models in this directory using the exact filenames below:

- brain_model.keras
- chest_model.keras
- teeth_model.keras
- knee_model.keras
- liver_model.keras
- hand_model.keras
- elbow_model.keras
- finger_model.keras
- forearm_model.keras
- humerus_model.keras
- shoulder_model.keras
- wrist_model.keras

Each Keras file must correspond to the TFLite model and labels JSON in
assets/ai_model/<model_name>/.

These large model files are intentionally ignored by Git. The Grad-CAM engine
verifies model input/output shapes and compares Keras and TFLite predictions
before returning a heatmap. A model architecture that cannot be reconstructed
or verified will be rejected instead of receiving a guessed heatmap.
