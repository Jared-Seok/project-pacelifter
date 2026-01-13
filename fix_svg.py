import os
import re
import glob

def fix_svg(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Extract styles
    style_block = re.search(r'<style>(.*?)</style>', content, re.DOTALL)
    styles = {}
    if style_block:
        css_content = style_block.group(1)
        # Regex to match .class { fill: ...; } or .class, .class2 { fill: ...; }
        for match in re.finditer(r'([^{]+)\{([^}]+)\}', css_content):
            selectors = match.group(1).split(',')
            props = match.group(2)
            fill_match = re.search(r'fill:\s*([^;]+);', props)
            opacity_match = re.search(r'fill-opacity:\s*([^;]+);', props)
            
            fill = fill_match.group(1).strip() if fill_match else None
            opacity = opacity_match.group(1).strip() if opacity_match else None
            
            for selector in selectors:
                selector = selector.strip()
                if selector.startswith('.'):
                    class_name = selector[1:]
                    styles[class_name] = {'fill': fill, 'opacity': opacity}

    # 2. Rename non-ASCII or underscore IDs
    ids = re.findall(r'id="([^"]+)"', content)
    id_map = {}
    ascii_counter = 0
    for old_id in ids:
        if any(ord(c) > 127 for c in old_id) or old_id.startswith('_'):
             new_id = f"fixed_id_{ascii_counter}"
             id_map[old_id] = new_id
             ascii_counter += 1
    
    new_content = content
    for old_id, new_id in id_map.items():
        new_content = new_content.replace(f'id="{old_id}"', f'id="{new_id}"')
        new_content = new_content.replace(f'url(#{old_id})', f'url(#{new_id})')

    # 3. Inline styles and remove class attributes
    def inline_style_replacer(match):
        class_content = match.group(1)
        style_string = ""
        classes = class_content.split()
        for cls in classes:
             if cls in styles:
                if styles[cls]['fill']:
                    fill_val = styles[cls]['fill']
                    # Handle remapped URLs in style definitions
                    for old_id, new_id in id_map.items():
                        fill_val = fill_val.replace(f'#{old_id}', f'#{new_id}')
                    style_string += f' fill="{fill_val}"'
                if styles[cls]['opacity']:
                    style_string += f' fill-opacity="{styles[cls]["opacity"]}"'
        return style_string

    new_content = re.sub(r'\s+class="([^"]+)"', inline_style_replacer, new_content)
    
    # 4. Remove the style block
    new_content = re.sub(r'<style>.*?</style>', '', new_content, flags=re.DOTALL)
    
    # 5. Fix potential non-ASCII attributes like data-name
    new_content = re.sub(r'data-name="[^"]+"', '', new_content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"Processed: {file_path}")

# Target directories
target_dirs = [
    'assets/images/strength/category',
    'assets/images/strength',
    'assets/images/endurance',
    'assets/images/strength/back',
    'assets/images/strength/biceps',
    'assets/images/strength/chest',
    'assets/images/strength/compound',
    'assets/images/strength/core',
    'assets/images/strength/forearms',
    'assets/images/strength/legs',
    'assets/images/strength/shoulders',
    'assets/images/strength/triceps',
]

for target_dir in target_dirs:
    print(f"Checking directory: {target_dir}")
    svg_files = glob.glob(os.path.join(target_dir, '*.svg'))
    for svg_file in svg_files:
        print(f"Fixing {svg_file}...")
        try:
            fix_svg(svg_file)
        except Exception as e:
            print(f"Failed to fix {svg_file}: {e}")
