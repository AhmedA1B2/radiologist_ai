import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

INPUT_SHAPE = (1, 224, 224, 3)


def load_labels(path: Path) -> list[str]:
    labels = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(labels, list) or not labels:
        raise ValueError("Chest labels must be a non-empty JSON list.")
    return [str(item) for item in labels]


def find_backbone(model: tf.keras.Model):
    for index, layer in enumerate(model.layers):
        if isinstance(layer, tf.keras.Model) and "densenet" in layer.name.lower():
            return index, layer
    raise RuntimeError(
        "Could not find the nested DenseNet backbone. "
        f"Top-level layers: {[layer.name for layer in model.layers]}"
    )


def find_target_layer(backbone: tf.keras.Model):
    for name in ("relu", "conv5_block16_concat"):
        try:
            layer = backbone.get_layer(name)
            if len(layer.output.shape) == 4:
                return layer
        except (ValueError, AttributeError):
            pass

    candidates = []
    for layer in backbone.layers:
        try:
            if len(layer.output.shape) == 4:
                candidates.append(layer)
        except (AttributeError, TypeError):
            continue
    if not candidates:
        raise RuntimeError("No 4D feature-map layer was found in DenseNet121.")
    return candidates[-1]


def build_gradcam_graph(model: tf.keras.Model):
    backbone_index, backbone = find_backbone(model)
    target_layer = find_target_layer(backbone)

    # A nested Functional model's own .input points at its internal Keras
    # InputLayer. For the parent graph, use the tensor that was actually fed
    # into the nested backbone call (after the model's preprocessing layers).
    inbound_nodes = getattr(backbone, "_inbound_nodes", [])
    backbone_call_input = None
    for node in reversed(inbound_nodes):
        node_inputs = getattr(node, "input_tensors", None)
        if node_inputs is not None:
            if isinstance(node_inputs, (list, tuple)):
                if len(node_inputs) != 1:
                    raise RuntimeError("Expected a single input to the DenseNet backbone.")
                backbone_call_input = node_inputs[0]
            else:
                backbone_call_input = node_inputs
            break

    if backbone_call_input is None:
        raise RuntimeError(
            "Could not locate the input tensor connected to the nested DenseNet call."
        )

    preprocessing_model = tf.keras.Model(
        inputs=model.inputs,
        outputs=backbone_call_input,
        name="chest_preprocessing_to_densenet",
    )
    feature_model = tf.keras.Model(
        inputs=backbone.inputs,
        outputs=[target_layer.output, backbone.output],
        name="chest_densenet_gradcam_features",
    )
    head_layers = model.layers[backbone_index + 1:]
    if not head_layers:
        raise RuntimeError("No classification head found after DenseNet121.")
    return preprocessing_model, feature_model, head_layers, target_layer.name


def jet_colormap(gray: np.ndarray) -> np.ndarray:
    x = np.clip(gray.astype(np.float32), 0.0, 1.0)
    red = np.clip(1.5 - np.abs(4.0 * x - 3.0), 0.0, 1.0)
    green = np.clip(1.5 - np.abs(4.0 * x - 2.0), 0.0, 1.0)
    blue = np.clip(1.5 - np.abs(4.0 * x - 1.0), 0.0, 1.0)
    return (np.stack([red, green, blue], axis=-1) * 255.0).astype(np.uint8)


def read_input_tensor(path: Path) -> np.ndarray:
    values = np.fromfile(path, dtype="<f4")
    expected = int(np.prod(INPUT_SHAPE))
    if values.size != expected:
        raise ValueError(
            f"Received {values.size} float32 values; expected {expected} "
            f"for input shape {INPUT_SHAPE}."
        )
    tensor = values.reshape(INPUT_SHAPE)
    if not np.isfinite(tensor).all():
        raise ValueError("Input tensor contains NaN or infinite values.")
    return tensor


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a Grad-CAM explanation for the Chest Keras model."
    )
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--input-tensor", required=True, type=Path)
    parser.add_argument("--class-index", required=True, type=int)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    for required_file in (args.model, args.labels, args.input_tensor):
        if not required_file.is_file():
            raise FileNotFoundError(f"Required file not found: {required_file}")

    labels = load_labels(args.labels)
    if not 0 <= args.class_index < len(labels):
        raise IndexError(f"class-index must be between 0 and {len(labels)-1}.")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    input_tensor = read_input_tensor(args.input_tensor)

    print(f"Loading Keras model: {args.model}", flush=True)
    model = tf.keras.models.load_model(args.model, compile=False)

    model_image_shape = tuple(model.input_shape[1:])
    if model_image_shape != INPUT_SHAPE[1:]:
        raise ValueError(
            f"Model image shape {model_image_shape} does not match {INPUT_SHAPE[1:]}."
        )
    if int(model.output_shape[-1]) != len(labels):
        raise ValueError(
            f"Model outputs {model.output_shape[-1]} classes but labels contain {len(labels)}."
        )

    preprocessing_model, feature_model, head_layers, target_layer_name = (
        build_gradcam_graph(model)
    )

    model_input = np.clip(input_tensor[0], 0, 255).astype(np.uint8)
    model_input_path = args.output_dir / "model_input.png"
    Image.fromarray(model_input, mode="RGB").save(model_input_path)

    raw_tensor = tf.convert_to_tensor(input_tensor, dtype=tf.float32)
    preprocessed = preprocessing_model(raw_tensor, training=False)

    with tf.GradientTape() as tape:
        activations, backbone_output = feature_model(
            preprocessed,
            training=False,
        )
        value = backbone_output
        for layer in head_layers:
            if isinstance(layer, tf.keras.layers.Dropout):
                value = layer(value, training=False)
            else:
                value = layer(value)
        predictions = value
        target_score = predictions[:, args.class_index]

    gradients = tape.gradient(target_score, activations)
    if gradients is None:
        raise RuntimeError("Gradients are unavailable for the selected DenseNet layer.")

    weights = tf.reduce_mean(gradients, axis=(0, 1, 2))
    cam = tf.reduce_sum(activations[0] * weights, axis=-1)
    cam = tf.nn.relu(cam)
    maximum = float(tf.reduce_max(cam).numpy())
    if not np.isfinite(maximum) or maximum <= 1e-12:
        raise RuntimeError("Grad-CAM map is empty or numerically zero.")

    cam = cam / maximum
    cam_array = cam.numpy().astype(np.float32)
    prediction_array = predictions[0].numpy().astype(float)
    top_index = int(np.argmax(prediction_array))

    if top_index != args.class_index:
        raise RuntimeError(
            "Keras/TFLite class mismatch: Flutter selected "
            f"'{labels[args.class_index]}' (index {args.class_index}), while Keras "
            f"predicts '{labels[top_index]}' (index {top_index}). "
            "Grad-CAM was stopped to avoid showing an explanation for a different class. "
            "Check that both model files use the same trained weights."
        )

    heatmap_image = Image.fromarray(
        np.clip(cam_array * 255.0, 0, 255).astype(np.uint8),
        mode="L",
    ).resize((224, 224), Image.Resampling.BILINEAR)
    heatmap_gray = np.asarray(heatmap_image, dtype=np.float32) / 255.0
    rgb = jet_colormap(heatmap_gray)
    alpha = np.clip(heatmap_gray * 210.0, 0, 190).astype(np.uint8)
    rgba = np.dstack([rgb, alpha])

    heatmap_path = args.output_dir / "heatmap.png"
    Image.fromarray(rgba, mode="RGBA").save(heatmap_path)

    metadata = {
        "status": "ok",
        "model": args.model.name,
        "tensorflow_version": tf.__version__,
        "class_index": args.class_index,
        "class_label": labels[args.class_index],
        "keras_top_class_index": top_index,
        "keras_top_class_label": labels[top_index],
        "keras_top_confidence": float(prediction_array[top_index]),
        "predictions": [
            {"index": i, "label": labels[i], "confidence": float(score)}
            for i, score in enumerate(prediction_array)
        ],
        "layer_name": target_layer_name,
        "feature_map_shape": [int(v) for v in activations.shape[1:]],
        "heatmap_max": maximum,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "warning": (
            "Grad-CAM is a visual explanation of model sensitivity, not a precise "
            "lesion boundary or an independently validated medical finding."
        ),
        "model_input_image": str(model_input_path.resolve()),
        "heatmap_image": str(heatmap_path.resolve()),
    }
    result_path = args.output_dir / "result.json"
    result_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(metadata, ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"GRADCAM_ERROR: {type(exc).__name__}: {exc}", file=sys.stderr, flush=True)
        raise SystemExit(1)
