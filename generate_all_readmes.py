import os

ROOT = "mql5_experts_mt5"

def is_valid_image(filename):
    lower = filename.lower()
    return (
        lower.endswith((".png", ".jpg", ".jpeg", ".gif"))
        and not any(x in lower for x in ["avatar", "indicator", "expert", "logo"])
    )

def get_mq5_files(files):
    return [f for f in files if f.lower().endswith('.mq5')]

def get_images(files):
    return [f for f in files if is_valid_image(f)]

def generate_readme(folder, mq5_files, images):
    title = os.path.basename(folder)
    lines = [f"# {title}\n", "## Description"]
    lines.append(
        "This folder contains a professional trading expert advisor (EA) for MetaTrader 5.\n\n"
        "Below are example screenshots of the strategy in action.  \n"
        "*Feel free to explore, test, and improve!*\n\n"
        "*You can add a detailed description of the strategy, parameters, and usage here.*\n\n"
        "---\n\n"
        "If you find this project useful, please consider giving it a star, sharing it, or even sending a small donation to support further development. Thank you!\n"
    )
    for img in images:
        lines.append(f"![Screenshot]({img})")
    lines.append("\n## Files")
    for mq5 in mq5_files:
        lines.append(f"- `{mq5}`")
    lines.append("\n## How to use")
    lines.append("1. Copy the `.mq5` file to your MetaTrader 5 `Experts` folder.")
    lines.append("2. Compile in MetaEditor.")
    lines.append("3. Attach the expert to a chart.")
    lines.append("4. Configure parameters as needed.\n")
    return "\n".join(lines)

for subdir in os.listdir(ROOT):
    folder = os.path.join(ROOT, subdir)
    if os.path.isdir(folder):
        files = os.listdir(folder)
        mq5_files = get_mq5_files(files)
        images = get_images(files)
        if mq5_files:  # Only process if there is at least one .mq5 file
            readme_path = os.path.join(folder, "README.md")
            new_content = generate_readme(folder, mq5_files, images)
            # Write or overwrite README.md if missing or different
            if not os.path.exists(readme_path) or open(readme_path, encoding="utf-8").read() != new_content:
                with open(readme_path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                print(f"README.md updated in: {folder}")

print("Vérification et génération terminées pour tous les dossiers !") 