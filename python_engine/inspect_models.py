
import os
import gc
import json
from pathlib import Path

os.environ.setdefault("TF_NUM_INTRAOP_THREADS", "2")
os.environ.setdefault("TF_NUM_INTEROP_THREADS", "2")
os.environ.setdefault("OMP_NUM_THREADS", "2")

import tensorflow as tf

BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"
ASSETS_DIR = BASE_DIR.parent / "assets" / "ai_model"


def get_shape(tensor):
    try:
        return tuple(
            None if value is None else int(value)
            for value in tensor.shape
        )
    except Exception:
        return None


def inspect_feature_layers(model):
    candidates = []

    def walk(container, prefix=""):
        for layer in container.layers:
            layer_path = f"{prefix}{layer.name}"

            if isinstance(layer, tf.keras.Model):
                walk(layer, layer_path + "/")
                continue

            output = getattr(layer, "output", None)
            if output is None:
                continue

            outputs = output if isinstance(output, (list, tuple)) else [output]

            for tensor in outputs:
                shape = get_shape(tensor)

                if shape is not None and len(shape) == 4:
                    candidates.append({
                        "name": layer_path,
                        "type": layer.__class__.__name__,
                        "shape": shape,
                    })

    walk(model)

    print("\nآخر طبقات استخراج الخصائص المكانية:")

    for item in candidates[-12:]:
        print(
            f"  {item['name']:<55} "
            f"{item['type']:<20} "
            f"{item['shape']}"
        )

    return candidates


def inspect_tflite(model_name):
    folder = ASSETS_DIR / model_name
    model_path = folder / f"{model_name}.tflite"

    labels_name = model_name.replace("_model", "_labels") + ".json"
    labels_path = folder / labels_name

    if not model_path.exists():
        print("  TFLite: الملف غير موجود:", model_path)
        return

    try:
        interpreter = tf.lite.Interpreter(
            model_path=str(model_path),
            num_threads=2,
        )
        interpreter.allocate_tensors()

        inputs = interpreter.get_input_details()
        outputs = interpreter.get_output_details()

        for item in inputs:
            print(
                "  TFLite input:",
                item["shape"],
                item["dtype"],
            )

        for item in outputs:
            print(
                "  TFLite output:",
                item["shape"],
                item["dtype"],
            )

        del interpreter

    except Exception as error:
        print("  TFLite inspection failed:", error)

    if labels_path.exists():
        try:
            labels = json.loads(
                labels_path.read_text(encoding="utf-8")
            )
            count = len(labels)
            print("  Labels count:", count)
        except Exception as error:
            print("  Labels error:", error)
    else:
        print("  Labels file missing:", labels_path)


def main():
    if not MODELS_DIR.exists():
        print("Models folder not found:", MODELS_DIR)
        return

    files = sorted(
        list(MODELS_DIR.glob("*.keras"))
        + list(MODELS_DIR.glob("*.h5"))
        + list(MODELS_DIR.glob("*.hdf5"))
    )

    if not files:
        print("No Keras models found in:", MODELS_DIR)
        return

    print("Found", len(files), "Keras model(s).")

    for model_path in files:
        print("\n" + "=" * 90)
        print("MODEL:", model_path.name)
        print("=" * 90)

        model = None

        try:
            model = tf.keras.models.load_model(
                model_path,
                compile=False,
            )

            print("Keras input shape:", model.input_shape)
            print("Keras output shape:", model.output_shape)

            model_name = model_path.stem

            inspect_feature_layers(model)
            inspect_tflite(model_name)

        except Exception as error:
            print("MODEL INSPECTION FAILED:", repr(error))

        finally:
            if model is not None:
                del model

            tf.keras.backend.clear_session()
            gc.collect()


if __name__ == "__main__":
    main()
