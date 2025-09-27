# This script:
#  - loads the dataset (csv/jsonl)
#  - loads the latest joblib model produced earlier (contains pipeline + label encoder)
#  - selects templates (random or TF-IDF)
#  - fills placeholders {first_name}, {last_name}, {age}, appends promo/link
#  - runs model.predict (and predict_proba or decision_function if available)
#  - saves results to test_results.csv

import json
from pathlib import Path
import random
import sys
import joblib
import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import datetime

DATA_CANDIDATES = [
    Path("english_personal_templates.csv"),
    Path("english_personal_templates.jsonl"),
    Path("persian_personalized_sentences.csv")
]
MODEL_DIR = Path("model_outputs")
OUT_CSV = Path("test_results.csv")
RANDOM_SEED = 42

random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)


def find_latest_model(model_dir=MODEL_DIR):
    if not model_dir.exists():
        raise FileNotFoundError(f"Model directory '{model_dir}' not found.")
    files = sorted([p for p in model_dir.glob("*.joblib")], key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        raise FileNotFoundError(f"No .joblib model files found in {model_dir}.")
    return files[0]


def load_model(joblib_path):
    print(f"[+] Loading model from {joblib_path}")
    data = joblib.load(joblib_path)
    if isinstance(data, dict) and "model" in data:
        model = data["model"]
        label_encoder = data.get("label_encoder", None)
    else:
        model = data
        label_encoder = None
    return model, label_encoder


def load_dataset(candidates=DATA_CANDIDATES):
    for p in candidates:
        if p.exists():
            print(f"[+] Loading dataset {p}")
            if p.suffix.lower() == ".csv":
                df = pd.read_csv(p, encoding="utf-8")
            elif p.suffix.lower() == ".jsonl":
                rows = []
                with p.open("r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line:
                            continue
                        rows.append(json.loads(line))
                df = pd.DataFrame(rows)
            else:
                df = pd.read_json(p, lines=True)
            cols_lower = {c.lower(): c for c in df.columns}
            if 'template' in cols_lower:
                text_col = cols_lower['template']
            elif 'example_filled' in cols_lower:
                text_col = cols_lower['example_filled']
            elif 'completion' in cols_lower:
                text_col = cols_lower['completion']
            else:
                text_col = df.columns[0]
            out = pd.DataFrame({"template": df[text_col].astype(str).fillna("")})
            return out
    raise FileNotFoundError("No dataset file found. Put english_personal_templates.csv or .jsonl in working dir.")


def select_random(df, n=5):
    n = min(n, len(df))
    idx = random.sample(list(df.index), n)
    sel = df.loc[idx].copy().reset_index(drop=True)
    sel['score_selection'] = 1.0
    sel['selection_method'] = 'random'
    return sel


def select_tfidf(df, query, n=5, ngram_range=(1,2), min_df=1):
    corpus = df['template'].fillna("").tolist()
    vec = TfidfVectorizer(ngram_range=ngram_range, min_df=min_df, sublinear_tf=True)
    X = vec.fit_transform(corpus)
    q_vec = vec.transform([query])
    sims = cosine_similarity(q_vec, X).flatten()
    top_idx = np.argsort(-sims)[:n]
    sel = df.iloc[top_idx].copy().reset_index(drop=True)
    sel['score_selection'] = sims[top_idx]
    sel['selection_method'] = 'tfidf'
    return sel


def fill_placeholders(text, first_name, last_name, age, promo_text=None):
    filled = text.replace("{first_name}", first_name).replace("{last_name}", last_name).replace("{age}", str(age))
    if promo_text:
        filled = filled.strip()
        if not filled.endswith((".", "!", "?", ",")):
            filled += "."
        filled = filled + "\n\n" + promo_text
    return filled


def run_inference(model, label_encoder, texts):
    out = []
    try:
        preds = model.predict(texts)
    except Exception as e:
        raise RuntimeError(f"Model prediction failed: {e}")
    probs = None
    scores = None
    try:
        if hasattr(model, "predict_proba"):
            probs = model.predict_proba(texts)
    except Exception:
        probs = None
    try:
        if hasattr(model, "decision_function") and probs is None:
            scores = model.decision_function(texts)
    except Exception:
        scores = None

    for i, p in enumerate(preds):
        rec = {"predicted_label": p}
        if label_encoder is not None:
            try:
                rec["predicted_label_str"] = label_encoder.inverse_transform([p])[0]
            except Exception:
                rec["predicted_label_str"] = str(p)
        else:
            rec["predicted_label_str"] = str(p)
        if probs is not None:
            max_idx = int(np.argmax(probs[i]))
            rec["score"] = float(probs[i][max_idx])
            rec["prob_vector"] = probs[i].tolist()
        elif scores is not None:
            try:
                if len(np.shape(scores)) == 1:
                    rec["score"] = float(scores[i])
                    rec["score_vector"] = None
                else:
                    rec["score"] = float(np.max(scores[i]))
                    rec["score_vector"] = scores[i].tolist()
            except Exception:
                rec["score"] = None
        else:
            rec["score"] = None
        out.append(rec)
    return out


def main_interactive():
    print("=== Test-only inference: load model + dataset and run predictions ===")
    try:
        dataset = load_dataset()
    except Exception as e:
        print("Error loading dataset:", e)
        sys.exit(1)

    try:
        model_file = find_latest_model()
    except Exception as e:
        print("Error finding model:", e)
        sys.exit(1)

    model, label_encoder = load_model(model_file)

    first_name = input("Enter first name (default Alex): ").strip() or "Alex"
    last_name = input("Enter last name (default Morgan): ").strip() or "Morgan"
    age = input("Enter age (default 34): ").strip() or "34"
    try:
        age_int = int(age)
    except Exception:
        age_int = age

    method = input("Selection method: 'random' or 'tfidf' (default random): ").strip().lower() or "random"
    n = input("How many templates to test? (default 5): ").strip()
    try:
        n = int(n)
    except Exception:
        n = 5

    promo = input("Optional promo/link text to append (empty for none): ").strip() or None

    if method == "tfidf":
        query = input("Enter short query describing desired tone/topic (for TF-IDF search): ").strip()
        if not query:
            print("[!] Empty query -> falling back to random selection.")
            selected = select_random(dataset, n=n)
        else:
            selected = select_tfidf(dataset, query=query, n=n)
    else:
        selected = select_random(dataset, n=n)

    filled_texts = []
    for idx, row in selected.iterrows():
        t = row["template"]
        filled = fill_placeholders(t, first_name, last_name, age_int, promo_text=promo)
        filled_texts.append(filled)

    try:
        inf_results = run_inference(model, label_encoder, filled_texts)
    except Exception as e:
        print("Inference failed:", e)
        sys.exit(1)

    rows = []
    ts = datetime.datetime.utcnow().isoformat() + "Z"
    for i, (row_sel, filled, inf) in enumerate(zip(selected.itertuples(), filled_texts, inf_results)):
        r = {
            "generated_at_utc": ts,
            "model_file": str(model_file),
            "selection_method": row_sel.selection_method if hasattr(row_sel, "selection_method") else "random",
            "selection_score": float(row_sel.score_selection) if hasattr(row_sel, "score_selection") else 1.0,
            "template_orig": row_sel.template,
            "filled_text": filled,
            "predicted_label": inf.get("predicted_label"),
            "predicted_label_str": inf.get("predicted_label_str"),
            "predicted_score": inf.get("score"),
            "extra_score_vector": json.dumps(inf.get("prob_vector") or inf.get("score_vector") or [])
        }
        rows.append(r)

    outdf = pd.DataFrame(rows)
    outdf.to_csv(OUT_CSV, index=False, encoding="utf-8")
    print(f"[+] Saved test results to {OUT_CSV.resolve()}\n")

    print("--- Samples and predictions ---\n")
    for i, r in outdf.iterrows():
        print(f"Sample #{i+1} (method={r['selection_method']}, sel_score={r['selection_score']})")
        print(r['filled_text'])
        print("-> Pred:", r['predicted_label_str'], "| score:", r['predicted_score'])
        print("-" * 80)

    print("Done.")


if __name__ == "__main__":
    main_interactive()
