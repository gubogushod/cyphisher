import os
import json
import random
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

from sklearn.dummy import DummyClassifier
from sklearn.svm import LinearSVC
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.pipeline import Pipeline
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
from sklearn.preprocessing import LabelEncoder
import joblib

DATA_PATHS = [
    Path("english_personal_templates.csv"),
    Path("english_personal_templates.jsonl"),
    Path("english_personal_templates.json"),
]
RANDOM_STATE = 42
TEST_SIZE = 0.2
CV_FOLDS = 4
OUT_DIR = Path("model_outputs")
OUT_DIR.mkdir(exist_ok=True)

def read_possible_files():
    for p in DATA_PATHS:
        if p.exists():
            print(f"[+] Loading {p}")
            if p.suffix.lower() == ".csv":
                df = pd.read_csv(p, encoding="utf-8")
            elif p.suffix.lower() == ".jsonl":
                rows = []
                with p.open("r", encoding="utf-8") as f:
                    for line in f:
                        if not line.strip():
                            continue
                        try:
                            rows.append(json.loads(line))
                        except Exception:
                            pass
                df = pd.DataFrame(rows)
            elif p.suffix.lower() == ".json":
                df = pd.read_json(p, lines=True)
            else:
                continue

            cols = {c.lower(): c for c in df.columns}
            if "example_filled" in cols:
                text_col = cols["example_filled"]
            elif "completion" in cols:
                text_col = cols["completion"]
            elif "template" in cols:
                text_col = cols["template"]
            else:
                text_col = df.columns[0]

            if "final_input" in cols:
                label_col = cols["final_input"]
            elif "label" in cols:
                label_col = cols["label"]
            else:
                label_col = None

            out = pd.DataFrame({
                "text": df[text_col].astype(str)
            })
            if label_col:
                out["label"] = df[label_col].astype(str).fillna("").replace({"": None})
            else:
                out["label"] = None
            return out
    raise FileNotFoundError("No input dataset found. Put english_personal_templates.csv or .jsonl in working dir.")

def heuristics_make_labels(df):
    print("[!] No labels detected. Creating heuristic labels for demo purposes.")
    def pick_label(text):
        t = text.lower()
        if "warm regards" in t or "warmly" in t:
            return "warm"
        if "sincerely" in t or "best wishes" in t or "looking forward" in t:
            return "formal"
        if "please reply" in t or "if this sounds interesting" in t:
            return "cta"
        if "capstone" in t or "project" in t:
            return "project"
        ln = len(t)
        if ln < 180:
            return "short"
        elif ln < 320:
            return "medium"
        else:
            return "long"
    return df["text"].apply(pick_label)

def prepare_data():
    df = read_possible_files()
    if df["label"].isnull().all():
        df["label"] = heuristics_make_labels(df)
    df = df.dropna(subset=["text", "label"]).reset_index(drop=True)
    print(f"[+] Dataset size: {len(df)} rows. Label distribution:")
    print(df["label"].value_counts())
    return df

def build_pipelines(random_state=RANDOM_STATE):
    """Return dict of name->pipeline objects"""
    tfidf = TfidfVectorizer(ngram_range=(1,2), max_df=0.9, min_df=2, sublinear_tf=True)
    pipelines = {
        "dummy_random": Pipeline([
            ("tfidf", tfidf),
            ("dummy", DummyClassifier(strategy="stratified", random_state=random_state))
        ]),
        "tfidf_rf": Pipeline([
            ("tfidf", tfidf),
            ("rf", RandomForestClassifier(random_state=random_state, n_jobs=-1))
        ]),
        "tfidf_svm": Pipeline([
            ("tfidf", tfidf),
            ("svc", LinearSVC(random_state=random_state, max_iter=10000))
        ])
    }
    return pipelines

def grid_search_rf(X_train, y_train, pipeline):
    """Run GridSearchCV on the RandomForest pipeline for a few params"""
    param_grid = {
        "rf__n_estimators": [100, 250],
        "rf__max_features": ["sqrt", 0.5],
        "rf__max_depth": [None, 30]
    }
    gs = GridSearchCV(pipeline, param_grid, cv=CV_FOLDS, scoring="accuracy", n_jobs=-1, verbose=1)
    gs.fit(X_train, y_train)
    print("[+] GridSearchCV best params:", gs.best_params_)
    print("[+] best CV score:", gs.best_score_)
    return gs.best_estimator_

def evaluate_model(name, model, X_test, y_test, label_encoder=None):
    preds = model.predict(X_test)
    acc = accuracy_score(y_test, preds)
    print(f"\n=== Results for {name} ===")
    print("Accuracy:", acc)
    print("Classification report:")
    print(classification_report(y_test, preds))
    # confusion matrix
    labels = np.unique(np.concatenate([y_test, preds]))
    cm = confusion_matrix(y_test, preds, labels=labels)
    plt.figure(figsize=(8,6))
    sns.heatmap(cm, annot=True, fmt="d", xticklabels=labels, yticklabels=labels, cmap="Blues")
    plt.ylabel("True")
    plt.xlabel("Predicted")
    plt.title(f"Confusion Matrix ({name})")
    plt.tight_layout()
    plt.savefig(OUT_DIR / f"confusion_{name}.png")
    plt.close()
    print(f"[+] confusion matrix saved to {OUT_DIR / f'confusion_{name}.png'}")
    return acc

def main():
    random.seed(RANDOM_STATE)
    np.random.seed(RANDOM_STATE)

    df = prepare_data()
    X = df["text"].values
    y_raw = df["label"].values
    le = LabelEncoder()
    y = le.fit_transform(y_raw)

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=TEST_SIZE,
                                                        stratify=y, random_state=RANDOM_STATE)

    pipelines = build_pipelines()

    results = {}
    print("\n[*] Training baseline DummyClassifier (random/stratified)...")
    pipelines["dummy_random"].fit(X_train, y_train)
    results["dummy_random"] = evaluate_model("dummy_random", pipelines["dummy_random"], X_test, y_test)

    print("\n[*] Tuning TF-IDF + RandomForest with GridSearchCV...")
    rf_best = grid_search_rf(X_train, y_train, pipelines["tfidf_rf"])
    results["tfidf_rf"] = evaluate_model("tfidf_rf", rf_best, X_test, y_test)

    print("\n[*] Training TF-IDF + LinearSVC (no heavy tuning)...")
    pipelines["tfidf_svm"].fit(X_train, y_train)
    results["tfidf_svm"] = evaluate_model("tfidf_svm", pipelines["tfidf_svm"], X_test, y_test)

    best_name = max(results, key=lambda k: results[k])
    print(f"\n[+] Best model: {best_name} (accuracy={results[best_name]:.4f})")

    best_model = rf_best if best_name == "tfidf_rf" else pipelines[best_name]

    ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    model_path = OUT_DIR / f"best_model_{best_name}_{ts}.joblib"
    joblib.dump({
        "model": best_model,
        "label_encoder": le,
        "config": {"random_state": RANDOM_STATE, "test_size": TEST_SIZE}
    }, model_path)
    print(f"[+] Saved best model + label encoder to {model_path}")

if __name__ == "__main__":
    main()




