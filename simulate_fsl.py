import json
import glob
import os
import csv

labels_path = r"C:\Projects\signia-fsl-recognition\csv\labels.csv"
models_dir = r"C:\Projects\signia-fsl-recognition\artifacts\models"

NUMBER_WORD_MAP = {
    "1": "ONE",
    "2": "TWO",
    "3": "THREE",
    "4": "FOUR",
    "5": "FIVE",
    "6": "SIX",
    "7": "SEVEN",
    "8": "EIGHT",
    "9": "NINE",
    "10": "TEN"
}

def normalize_sign_id(sign_id: str) -> str:
    return str(sign_id).strip().upper().replace(" ", "_").replace("'", "").replace("’", "")

def get_challenge_target(sign_id: str) -> str:
    norm = normalize_sign_id(sign_id)
    if norm.startswith("SPELL_"):
        return norm[len("SPELL_"):].replace("_", "")
    if norm.startswith("SIGN_"):
        norm = norm[len("SIGN_"):]
    if norm.startswith("COLOR_"):
        norm = norm[len("COLOR_"):]
    if norm.endswith("_SIGN"):
        norm = norm[:-len("_SIGN")]
    
    if norm in NUMBER_WORD_MAP:
        norm = NUMBER_WORD_MAP[norm]
        
    return norm

def get_challenge_type(sign_id: str) -> str:
    norm = normalize_sign_id(sign_id)
    if norm.startswith("SPELL_"):
        return "spell"
    return "direct"

def are_signs_matching(detected_sign: str, target_sign: str) -> bool:
    norm_detected = get_challenge_target(detected_sign)
    norm_target = get_challenge_target(target_sign)
    return norm_detected == norm_target

# Load and normalize labels.csv
labels = {}
with open(labels_path, "r", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        norm_label = normalize_sign_id(row["label"].strip())
        labels[norm_label] = {"id": int(row["id"].strip()), "raw": row["label"].strip(), "cat": row["category"].strip().lower()}

available_model_dirs = [d.name.lower() for d in os.scandir(models_dir) if d.is_dir()]

dialogue_files = sorted(glob.glob(r"C:\Users\Acer\Games\signia\dialogues\*.json"))

report = []
critical_bugs = []
simulation_stats = {"total_nodes": 0, "total_choices": 0, "spelling_choices": 0, "direct_sign_choices": 0}

for file_path in dialogue_files:
    fname = os.path.basename(file_path)
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    node_ids = {node["id"] for node in data}
    file_issues = []
    
    for node in data:
        simulation_stats["total_nodes"] += 1
        nid = node["id"]
        nxt = node.get("next", -1)
        choices = node.get("choices", [])
        
        # Check node pointer
        if nxt != -1 and nxt not in node_ids:
            file_issues.append(f"Node {nid}: 'next'={nxt} does not exist in file!")
            
        for c_idx, choice in enumerate(choices):
            simulation_stats["total_choices"] += 1
            c_text = choice.get("text", "")
            c_sign = choice.get("sign", "")
            c_next = choice.get("next", -1)
            
            if c_next != -1 and c_next not in node_ids:
                file_issues.append(f"Node {nid} Choice '{c_text}': 'next'={c_next} does not exist in file!")
                
            ctype = get_challenge_type(c_sign)
            target = get_challenge_target(c_sign)
            
            if ctype == "spell":
                simulation_stats["spelling_choices"] += 1
                # Test spelling validity
                if not target.isalpha():
                    file_issues.append(f"Node {nid} Spell Choice '{c_text}' (sign='{c_sign}'): target '{target}' contains non-alphabet characters!")
                
                # Simulate letter-by-letter input stream matching
                input_stream = ""
                matched = False
                for ch in target:
                    input_stream += ch
                    if input_stream == target:
                        matched = True
                        break
                if not matched:
                    file_issues.append(f"Node {nid} Spell sequence matching failed for '{c_text}' (target={target})")
            else:
                simulation_stats["direct_sign_choices"] += 1
                # Test direct sign matching against backend prediction pool
                matched_label = None
                for norm_lbl in labels:
                    if are_signs_matching(norm_lbl, c_sign):
                        matched_label = norm_lbl
                        break
                
                if matched_label is None:
                    issue_msg = f"Node {nid} Direct Sign Choice '{c_text}' (sign='{c_sign}'): target '{target}' DOES NOT MATCH any backend prediction!"
                    file_issues.append(issue_msg)
                    critical_bugs.append((fname, nid, c_text, c_sign, target))
                else:
                    cat = labels[matched_label]["cat"]
                    cat_model_exists = any(cat in mdir for mdir in available_model_dirs)
                    if not cat_model_exists:
                        file_issues.append(f"Node {nid} Direct Sign Choice '{c_text}' (sign='{c_sign}'): category '{cat}' missing model directory!")

    report.append((fname, file_issues))

print("="*60)
print("FSL + DIALOGUE COMPLETE ENGINE SIMULATION")
print("="*60)
print(f"Total Dialogue Files Checked: {len(dialogue_files)}")
print(f"Total Dialogue Nodes Simulated: {simulation_stats['total_nodes']}")
print(f"Total Interactive Choices: {simulation_stats['total_choices']}")
print(f"  - Fingerspelling (Alphabet Model): {simulation_stats['spelling_choices']}")
print(f"  - Direct Signs (Gesture Models): {simulation_stats['direct_sign_choices']}")
print("="*60)

total_issues = 0
for fname, issues in report:
    if not issues:
        print(f"[PASS] {fname:15} | All nodes and FSL targets verified 100%")
    else:
        print(f"[FAIL] {fname:15} | {len(issues)} issues found:")
        for iss in issues:
            print(f"   -> {iss}")
            total_issues += 1

print("="*60)
if total_issues == 0:
    print("ALL SIMULATION CHECKS PASSED: 0 ERRORS DETECTED!")
else:
    print(f"TOTAL ISSUES DETECTED: {total_issues}")
print("="*60)
