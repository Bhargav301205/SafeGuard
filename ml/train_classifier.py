"""
SafeGuard ML — False-Positive Classifier Training
Trains a lightweight logistic classifier to distinguish genuine vehicle crashes
from common false-positive events (phone drops, jogging, harsh braking, bumps).
Exports model weights to JSON for easy on-device inference in Flutter or backend.
"""

import os
import json
import numpy as np
import pandas as pd

DATA_PATH = os.path.join(os.path.dirname(__file__), "data", "synthetic_crash_data.csv")
OUTPUT_MODEL_PATH = os.path.join(os.path.dirname(__file__), "model_weights.json")

FEATURES = [
    "peak_g",
    "angular_velocity_dps",
    "speed_drop_kmh",
    "post_impact_variance",
]


def sigmoid(z):
    return 1.0 / (1.0 + np.exp(-np.clip(z, -15, 15)))


def train():
    print(f"[ML] Loading dataset from: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH)
    print(f"[ML] Total samples: {len(df)} (Crashes: {(df['is_crash'] == 1).sum()}, Non-crashes: {(df['is_crash'] == 0).sum()})")

    X_raw = df[FEATURES].values.astype(np.float32)
    y = df["is_crash"].values.astype(np.float32)

    # Compute normalization parameters
    means = np.mean(X_raw, axis=0)
    stds = np.std(X_raw, axis=0) + 1e-6
    X = (X_raw - means) / stds

    # Initialize weights and bias
    np.random.seed(42)
    w = np.random.randn(X.shape[1]) * 0.1
    b = 0.0

    # Gradient descent training
    lr = 0.05
    epochs = 600
    l2_reg = 0.01

    for epoch in range(epochs):
        z = np.dot(X, w) + b
        preds = sigmoid(z)
        loss = -np.mean(y * np.log(preds + 1e-7) + (1 - y) * np.log(1 - preds + 1e-7)) + 0.5 * l2_reg * np.sum(w ** 2)

        # Gradients
        dz = preds - y
        dw = (np.dot(X.T, dz) / len(y)) + (l2_reg * w)
        db = np.mean(dz)

        w -= lr * dw
        b -= lr * db

        if (epoch + 1) % 100 == 0:
            acc = np.mean((preds >= 0.5) == y) * 100
            print(f"[ML] Epoch {epoch+1}/{epochs} - Loss: {loss:.4f} - Accuracy: {acc:.1f}%")

    # Final Evaluation
    final_preds = sigmoid(np.dot(X, w) + b)
    pred_labels = (final_preds >= 0.5).astype(int)
    final_acc = np.mean(pred_labels == y) * 100
    print(f"\n[ML] Training Complete! Final Accuracy: {final_acc:.2f}%")

    # Serialize weights for on-device or backend inference
    model_spec = {
        "model_type": "LogisticRegressionClassifier",
        "version": "1.0.0",
        "features": FEATURES,
        "feature_means": means.tolist(),
        "feature_stds": stds.tolist(),
        "weights": w.tolist(),
        "bias": float(b),
        "decision_threshold": 0.5,
        "accuracy": round(float(final_acc), 2),
    }

    with open(OUTPUT_MODEL_PATH, "w") as f:
        json.dump(model_spec, f, indent=2)

    print(f"[ML] Saved model specification and weights to: {OUTPUT_MODEL_PATH}")
    return model_spec


if __name__ == "__main__":
    train()
