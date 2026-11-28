import sys
import unittest
from pathlib import Path

import numpy as np
import tensorflow as tf

ENGINE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ENGINE_DIR))

import gradcam_cli


class GradCamGraphTests(unittest.TestCase):
    def setUp(self):
        tf.keras.backend.clear_session()
        self.image = np.random.default_rng(123).uniform(
            0.0, 255.0, size=(1, 32, 32, 3)
        ).astype(np.float32)

    def test_dynamic_batch_input_shape_is_normalized_to_one(self):
        inputs = tf.keras.Input(shape=(32, 32, 3))
        outputs = tf.keras.layers.GlobalAveragePooling2D()(
            tf.keras.layers.Conv2D(4, 3, activation="relu")(inputs)
        )
        model = tf.keras.Model(inputs, tf.keras.layers.Dense(2)(outputs))

        self.assertEqual(
            gradcam_cli.static_nhwc_shape(model),
            (1, 32, 32, 3),
        )

    def test_direct_functional_cnn_generates_nonempty_cam(self):
        inputs = tf.keras.Input(shape=(32, 32, 3))
        x = tf.keras.layers.Conv2D(8, 3, activation="relu")(inputs)
        x = tf.keras.layers.Conv2D(8, 3, activation="relu")(x)
        x = tf.keras.layers.GlobalAveragePooling2D()(x)
        outputs = tf.keras.layers.Dense(3, activation="softmax")(x)
        model = tf.keras.Model(inputs, outputs)

        forward, layer_name, data_format = gradcam_cli.build_forward_graph(model)
        cam, scores, feature_shape = gradcam_cli.compute_gradcam(
            forward, self.image, 1, data_format
        )

        self.assertTrue(layer_name)
        self.assertEqual(scores.shape, (3,))
        self.assertEqual(len(feature_shape), 3)
        self.assertTrue(np.isfinite(cam).all())
        self.assertGreater(float(cam.max()), 0.0)

    def test_nested_backbone_with_sequential_head_generates_cam(self):
        backbone_input = tf.keras.Input(shape=(32, 32, 3))
        x = tf.keras.layers.Conv2D(8, 3, activation="relu")(backbone_input)
        x = tf.keras.layers.Conv2D(8, 3, activation="relu")(x)
        x = tf.keras.layers.GlobalAveragePooling2D()(x)
        backbone = tf.keras.Model(backbone_input, x, name="tiny_backbone")

        model_input = tf.keras.Input(shape=(32, 32, 3))
        x = backbone(model_input)
        x = tf.keras.layers.Dropout(0.1)(x)
        output = tf.keras.layers.Dense(3, activation="softmax")(x)
        model = tf.keras.Model(model_input, output)

        forward, layer_name, data_format = gradcam_cli.build_forward_graph(model)
        baseline = model(self.image, training=False).numpy().reshape(-1)
        activations, reconstructed = forward(tf.convert_to_tensor(self.image))
        reconstructed_scores = reconstructed.numpy().reshape(-1)

        np.testing.assert_allclose(
            baseline, reconstructed_scores, rtol=1e-4, atol=1e-5
        )

        cam, scores, feature_shape = gradcam_cli.compute_gradcam(
            forward, self.image, int(np.argmax(baseline)), data_format
        )
        self.assertIn("tiny_backbone/", layer_name)
        self.assertEqual(scores.shape, (3,))
        self.assertEqual(len(feature_shape), 3)
        self.assertTrue(np.isfinite(cam).all())
        self.assertGreater(float(cam.max()), 0.0)

    def test_model_without_spatial_layer_is_rejected(self):
        inputs = tf.keras.Input(shape=(32,))
        outputs = tf.keras.layers.Dense(2)(inputs)
        model = tf.keras.Model(inputs, outputs)

        with self.assertRaises(RuntimeError):
            gradcam_cli.build_forward_graph(model)


if __name__ == "__main__":
    unittest.main()
