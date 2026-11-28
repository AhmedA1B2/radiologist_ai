"""
Generic Grad-CAM engine for all supported specialist Keras models.

The Flutter app supplies the exact RGB float32 tensor used by TFLite.
This script verifies that the selected Keras/TFLite/labels files agree before
writing an explanation. Unsupported model graphs fail closed; no guessed map
is returned.
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

SUPPORTED_MODELS = {
    "brain_model", "chest_model", "teeth_model", "knee_model",
    "liver_model", "hand_model", "elbow_model", "finger_model",
    "forearm_model", "humerus_model", "shoulder_model", "wrist_model",
}


def load_labels(path: Path) -> list[str]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(decoded, list):
        labels = [str(value).strip() for value in decoded]
    elif isinstance(decoded, dict):
        # Keep JSON insertion order. This mirrors AIPipelineService._parseLabels.
        labels = [str(value).strip() for value in decoded.values()]
    else:
        raise ValueError("Labels JSON must contain a list or an ordered object.")
    if not labels or any(not label for label in labels):
        raise ValueError("Labels JSON is empty or contains an empty label.")
    return labels


def one_tensor(value, description: str):
    if isinstance(value, (list, tuple, dict)):
        raise ValueError(f"{description} must be a single tensor, not multiple outputs.")
    return value


def static_nhwc_shape(model: tf.keras.Model) -> tuple[int, int, int, int]:
    shape = model.input_shape
    if isinstance(shape, list):
        if len(shape) != 1:
            raise ValueError(f"Only one model input is supported; got {shape}.")
        shape = shape[0]
    if shape is None or len(shape) != 4 or any(v is None for v in shape):
        raise ValueError(f"Model input must have a fixed NHWC rank-4 shape; got {shape}.")
    result = tuple(int(v) for v in shape)
    if result[0] != 1 or result[-1] not in (1, 3, 4):
        raise ValueError(
            f"Expected batch size 1 and channels-last input; got {result}. "
            "This Flutter integration currently sends RGB NHWC images."
        )
    return result


def layer_output_tensor(layer):
    output = getattr(layer, "output", None)
    if isinstance(output, (list, tuple)):
        if len(output) != 1:
            return None
        output = output[0]
    return output


def has_spatial_output(layer) -> bool:
    output = layer_output_tensor(layer)
    try:
        return output is not None and len(output.shape) == 4
    except (AttributeError, TypeError):
        return False


def find_last_direct_spatial_layer(container: tf.keras.Model):
    """Find the last rank-4 layer directly represented in this model graph."""
    for layer in reversed(container.layers):
        if has_spatial_output(layer):
            shape = tuple(layer_output_tensor(layer).shape)
            if len(shape) == 4 and shape[1] not in (None, 1) and shape[2] not in (None, 1):
                return layer
    return None


def nested_model_call_input(nested_model):
    nodes = getattr(nested_model, "_inbound_nodes", [])
    for node in reversed(nodes):
        inputs = getattr(node, "input_tensors", None)
        if inputs is None:
            continue
        if isinstance(inputs, (list, tuple)):
            if len(inputs) != 1:
                raise ValueError("Nested specialist model must have one input.")
            return inputs[0]
        return inputs
    raise RuntimeError(
        f"Could not find the parent-graph input for nested model '{nested_model.name}'."
    )


def call_layer_in_inference_mode(layer, value):
    try:
        return layer(value, training=False)
    except TypeError:
        return layer(value)


def build_forward_graph(model: tf.keras.Model):
    """
    Returns a callable that yields (spatial activations, class scores).

    Handles:
      1. Ordinary Functional/Sequential CNNs whose spatial layers are in the
         top-level graph.
      2. A common transfer-learning layout with a nested CNN backbone and a
         sequential classification head.

    If the nested-head reconstruction does not reproduce the original model
    output, the script stops rather than generating a misleading explanation.
    """
    # Prefer a nested feature extractor over a top-level preprocessing layer.
    for index in range(len(model.layers) - 1, -1, -1):
        nested = model.layers[index]
        if not isinstance(nested, tf.keras.Model):
            continue
        target = find_last_direct_spatial_layer(nested)
        if target is None:
            continue

        nested_input = nested_model_call_input(nested)
        preprocessing_model = tf.keras.Model(
            inputs=model.inputs,
            outputs=nested_input,
            name=f"{nested.name}_input_path",
        )
        feature_model = tf.keras.Model(
            inputs=nested.inputs,
            outputs=[layer_output_tensor(target), nested.output],
            name=f"{nested.name}_gradcam_features",
        )
        head_layers = model.layers[index + 1:]

        def nested_forward(input_tensor):
            value = preprocessing_model(input_tensor, training=False)
            activations, value = feature_model(value, training=False)
            for head_layer in head_layers:
                value = call_layer_in_inference_mode(head_layer, value)
            return activations, one_tensor(value, "Reconstructed classifier output")

        layer_name = f"{nested.name}/{target.name}"
        return nested_forward, layer_name

    # Standard top-level graph. This also covers a nested feature extractor
    # whose exposed output itself is a spatial feature map.
    target = find_last_direct_spatial_layer(model)
    if target is None:
        raise RuntimeError(
            "No rank-4 spatial feature layer was found. "
            "This architecture needs an explicit Grad-CAM layer mapping."
        )

    grad_model = tf.keras.Model(
        inputs=model.inputs,
        outputs=[layer_output_tensor(target), one_tensor(model.output, "Model output")],
        name=f"{model.name}_gradcam",
    )

    def direct_forward(input_tensor):
        activations, predictions = grad_model(input_tensor, training=False)
        return activations, one_tensor(predictions, "Model output")

    return direct_forward, target.name


def read_input_tensor(path: Path, expected_shape: tuple[int, int, int, int]) -> np.ndarray:
    values = np.fromfile(path, dtype="<f4")
    expected_count = int(np.prod(expected_shape))
    if values.size != expected_count:
        raise ValueError(
            f"Received {values.size} float32 values; expected {expected_count} "
            f"for model input shape {expected_shape}."
        )
    tensor = values.reshape(expected_shape)
    if not np.isfinite(tensor).all():
        raise ValueError("Input tensor contains NaN or infinite values.")
    return tensor


def dequantize_tflite_output(raw: np.ndarray, detail: dict) -> np.ndarray:
    if np.issubdtype(raw.dtype, np.integer):
        scale, zero_point = detail.get("quantization", (0.0, 0))
        if not scale:
            raise ValueError("Quantized TFLite output has no usable quantization scale.")
        return (raw.astype(np.float32) - float(zero_point)) * float(scale)
    return raw.astype(np.float32)


def prepare_tflite_input(tensor: np.ndarray, detail: dict) -> np.ndarray:
    dtype = detail["dtype"]
    if dtype == np.float32:
        return tensor.astype(np.float32, copy=False)
    if dtype == np.float16:
        return tensor.astype(np.float16)
    if np.issubdtype(dtype, np.integer):
        scale, zero_point = detail.get("quantization", (0.0, 0))
        if not scale:
            raise ValueError("Quantized TFLite input has no usable quantization scale.")
        quantized = np.rint(tensor / float(scale) + float(zero_point))
        limits = np.iinfo(dtype)
        return np.clip(quantized, limits.min, limits.max).astype(dtype)
    raise TypeError(f"Unsupported TFLite input dtype: {dtype}.")


def jet_colormap(gray: np.ndarray) -> np.ndarray:
    x = np.clip(gray.astype(np.float32), 0.0, 1.0)
    red = np.clip(1.5 - np.abs(4.0 * x - 3.0), 0.0, 1.0)
    green = np.clip(1.5 - np.abs(4.0 * x - 2.0), 0.0, 1.0)
    blue = np.clip(1.5 - np.abs(4.0 * x - 1.0), 0.0, 1.0)
    return (np.stack([red, green, blue], axis=-1) * 255.0).astype(np.uint8)


def compute_gradcam(forward, input_tensor: np.ndarray, class_index: int):
    tensor = tf.convert_to_tensor(input_tensor, dtype=tf.float32)
    with tf.GradientTape() as tape:
        activations, predictions = forward(tensor)
        predictions = one_tensor(predictions, "Classifier output")
        if len(predictions.shape) != 2:
            raise ValueError(
                f"Classifier output must have shape [1, classes]; got {predictions.shape}."
            )
        if class_index >= int(predictions.shape[-1]):
            raise IndexError(
                f"class-index {class_index} is outside model output range "
                f"0..{int(predictions.shape[-1]) - 1}."
            )
        score = predictions[:, class_index]

    gradients = tape.gradient(score, activations)
    if gradients is None:
        raise RuntimeError("Gradients are unavailable for the selected spatial layer.")

    if len(activations.shape) != 4:
        raise ValueError(f"Selected feature layer is not rank 4: {activations.shape}.")

    # Respect the selected layer's data format.
    data_format = getattr(tf.keras.backend, "image_data_format", lambda: "channels_last")()
    if data_format == "channels_first":
        weights = tf.reduce_mean(gradients, axis=(2, 3))
        cam = tf.reduce_sum(activations[0] * weights[0][:, None, None], axis=0)
    else:
        weights = tf.reduce_mean(gradients, axis=(1, 2))
        cam = tf.reduce_sum(activations[0] * weights[0][None, None, :], axis=-1)

    cam = tf.nn.relu(cam)
    maximum = float(tf.reduce_max(cam).numpy())
    if not np.isfinite(maximum) or maximum <= 1e-12:
        raise RuntimeError("Grad-CAM map is empty or numerically zero.")

    cam = cam / maximum
    scores = np.asarray(predictions[0].numpy(), dtype=np.float32).reshape(-1)
    return cam.numpy().astype(np.float32), scores, tuple(int(v) for v in activations.shape[1:])


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a verified Grad-CAM explanation for one specialist model."
    )
    parser.add_argument("--specialist", required=True)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--tflite-model", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--input-tensor", required=True, type=Path)
    parser.add_argument("--class-index", required=True, type=int)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    if args.specialist not in SUPPORTED_MODELS:
        raise ValueError(f"Unsupported specialist model name: {args.specialist}")

    for required_file in (args.model, args.tflite_model, args.labels, args.input_tensor):
        if not required_file.is_file():
            raise FileNotFoundError(f"Required file not found: {required_file}")

    labels = load_labels(args.labels)
    if not 0 <= args.class_index < len(labels):
        raise IndexError(f"class-index must be between 0 and {len(labels) - 1}.")

    args.output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading Keras model: {args.model}", flush=True)
    model = tf.keras.models.load_model(args.model, compile=False)
    input_shape = static_nhwc_shape(model)
    if input_shape[-1] != 3:
        raise ValueError(
            f"Flutter currently supplies RGB input with 3 channels; model expects {input_shape}."
        )
    input_tensor = read_input_tensor(args.input_tensor, input_shape)

    output_shape = model.output_shape
    if isinstance(output_shape, list) or len(output_shape) != 2:
        raise ValueError(f"Model must have one rank-2 classification output; got {output_shape}.")
    if int(output_shape[-1]) != len(labels):
        raise ValueError(
            f"Keras outputs {output_shape[-1]} classes but labels contain {len(labels)}."
        )

    forward, target_layer_name = build_forward_graph(model)

    # Prove the reconstructed forward graph reproduces the saved Keras model.
    baseline = one_tensor(model(tf.convert_to_tensor(input_tensor), training=False), "Model output")
    activations_check, reconstructed = forward(tf.convert_to_tensor(input_tensor))
    baseline_scores = np.asarray(baseline.numpy()).reshape(-1)
    reconstructed_scores = np.asarray(reconstructed.numpy()).reshape(-1)
    if baseline_scores.shape != reconstructed_scores.shape or not np.allclose(
        baseline_scores, reconstructed_scores, rtol=1e-4, atol=1e-5
    ):
        raise RuntimeError(
            "The selected feature path does not reproduce the original Keras output. "
            "This model graph needs an explicit Grad-CAM mapping; no heatmap was created."
        )

    interpreter = tf.lite.Interpreter(model_path=str(args.tflite_model), num_threads=2)
    interpreter.allocate_tensors()
    tflite_inputs = interpreter.get_input_details()
    tflite_outputs = interpreter.get_output_details()
    if len(tflite_inputs) != 1 or len(tflite_outputs) != 1:
        raise RuntimeError("Expected exactly one TFLite input and one output tensor.")

    tflite_input_shape = tuple(int(v) for v in tflite_inputs[0]["shape"])
    if tflite_input_shape != input_shape:
        raise ValueError(
            f"Keras input {input_shape} does not match TFLite input {tflite_input_shape}."
        )
    if tflite_inputs[0]["dtype"] not in (np.float32, np.float16) and not np.issubdtype(
        tflite_inputs[0]["dtype"], np.integer
    ):
        raise TypeError(f"Unsupported TFLite input dtype: {tflite_inputs[0]['dtype']}.")

    tflite_input = prepare_tflite_input(input_tensor, tflite_inputs[0])
    interpreter.set_tensor(tflite_inputs[0]["index"], tflite_input)
    interpreter.invoke()
    tflite_raw = interpreter.get_tensor(tflite_outputs[0]["index"])
    tflite_scores = dequantize_tflite_output(tflite_raw, tflite_outputs[0]).reshape(-1)

    if tflite_scores.size != len(labels):
        raise ValueError(
            f"TFLite returned {tflite_scores.size} values for {len(labels)} labels."
        )

    keras_top_index = int(np.argmax(baseline_scores))
    tflite_top_index = int(np.argmax(tflite_scores))
    if tflite_top_index != args.class_index:
        raise RuntimeError(
            f"Flutter selected class index {args.class_index}, but rerunning the "
            f"TFLite file selected {tflite_top_index}. Verify the asset and input tensor."
        )
    if keras_top_index != args.class_index:
        raise RuntimeError(
            f"TFLite selected '{labels[args.class_index]}' (index {args.class_index}), "
            f"but Keras selected '{labels[keras_top_index]}' (index {keras_top_index}). "
            "The two model files may not contain matching weights."
        )

    cam_array, prediction_array, feature_map_shape = compute_gradcam(
        forward, input_tensor, args.class_index
    )
    if int(np.argmax(prediction_array)) != args.class_index:
        raise RuntimeError("Grad-CAM forward pass class does not match the selected class.")

    height, width = input_shape[1], input_shape[2]
    heatmap_image = Image.fromarray(
        np.clip(cam_array * 255.0, 0, 255).astype(np.uint8)
    ).resize((width, height), Image.Resampling.BILINEAR)
    heatmap_gray = np.asarray(heatmap_image, dtype=np.float32) / 255.0

    original_rgb = np.clip(input_tensor[0], 0, 255).astype(np.uint8)
    if original_rgb.shape[-1] == 4:
        original_rgb = original_rgb[:, :, :3]
    original_image = Image.fromarray(original_rgb, mode="RGB")

    heatmap_rgb = jet_colormap(heatmap_gray)
    alpha = np.clip(heatmap_gray * 190.0, 0, 125).astype(np.uint8)
    heatmap_rgba = np.dstack([heatmap_rgb, alpha])

    input_path = args.output_dir / "model_input.png"
    heatmap_path = args.output_dir / "heatmap.png"
    overlay_path = args.output_dir / "overlay.png"
    original_image.save(input_path)
    Image.fromarray(heatmap_rgba, mode="RGBA").save(heatmap_path)
    overlay = Image.alpha_composite(
        original_image.convert("RGBA"),
        Image.fromarray(heatmap_rgba, mode="RGBA"),
    ).convert("RGB")
    overlay.save(overlay_path, quality=95)

    max_abs_difference = float(np.max(np.abs(prediction_array - tflite_scores)))
    mean_abs_difference = float(np.mean(np.abs(prediction_array - tflite_scores)))
    metadata = {
        "status": "ok",
        "specialist": args.specialist,
        "model": args.model.name,
        "tensorflow_version": tf.__version__,
        "class_index": args.class_index,
        "class_label": labels[args.class_index],
        "keras_top_class_index": keras_top_index,
        "tflite_top_class_index": tflite_top_index,
        "keras_top_confidence": float(prediction_array[args.class_index]),
        "tflite_top_score": float(tflite_scores[args.class_index]),
        "max_abs_probability_difference": max_abs_difference,
        "mean_abs_probability_difference": mean_abs_difference,
        "layer_name": target_layer_name,
        "feature_map_shape": list(feature_map_shape),
        "input_shape": list(input_shape),
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "warning": (
            "Grad-CAM is a model-sensitivity explanation. It does not establish "
            "a diagnosis, prove a lesion exists, or mark precise lesion boundaries. "
            "A qualified clinician must review the original image."
        ),
        "model_input_image": str(input_path.resolve()),
        "heatmap_image": str(heatmap_path.resolve()),
        "overlay_image": str(overlay_path.resolve()),
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
        print(
            f"GRADCAM_ERROR: {type(exc).__name__}: {exc}",
            file=sys.stderr,
            flush=True,
        )
        raise SystemExit(1)
