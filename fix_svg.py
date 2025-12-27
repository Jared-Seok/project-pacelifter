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
        # Simplified parser for this specific SVG format
        for match in re.finditer(r'([^{]+)\{([^}]+)\}', css_content):
            selectors = match.group(1).split(',')
            props = match.group(2)
            fill_match = re.search(r'fill:\s*([^;]+);', props)
            opacity_match = re.search(r'fill-opacity:\s*([^;]+);', props)
            
            fill = fill_match.group(1) if fill_match else None
            opacity = opacity_match.group(1) if opacity_match else None
            
            for selector in selectors:
                selector = selector.strip()
                if selector.startswith('.'):
                    class_name = selector[1:]
                    styles[class_name] = {'fill': fill, 'opacity': opacity}

    # 2. Rename Korean/Non-ASCII IDs
    # Find all IDs
    ids = re.findall(r'id="([^"]+)"', content)
    id_map = {}
    ascii_counter = 0
    for i, old_id in enumerate(ids):
        # check if non-ascii
        if any(ord(c) > 127 for c in old_id) or old_id.startswith('_'):
             new_id = f"gradient_{ascii_counter}"
             id_map[old_id] = new_id
             ascii_counter += 1
    
    # Replace ID definitions and references
    new_content = content
    for old_id, new_id in id_map.items():
        # Replace ID definition
        new_content = new_content.replace(f'id="{old_id}"', f'id="{new_id}"')
        # Replace URL references
        new_content = new_content.replace(f'url(#{old_id})', f'url(#{new_id})')

    # 3. Inline styles
    # Find tags with class attributes
    def replace_class(match):
        tag_start = match.group(1)
        classes = match.group(2).split()
        
        style_attrs = []
        
        # Keep existing fill if present (unlikely if using class)
        
        for cls in classes:
            if cls in styles:
                if styles[cls]['fill']:
                    # Check if fill contains a remapped URL
                    fill_val = styles[cls]['fill']
                    # Use regex to update url in style definition if it wasn't caught by global replace (it should have been caught if it matches exact string)
                    # Actually, we applied global replace on new_content, but styles dict has old values.
                    # We need to update fill_val references too.
                    for old_id, new_id in id_map.items():
                        if f'#{old_id}' in fill_val:
                            fill_val = fill_val.replace(f'#{old_id}', f'#{new_id}')
                    
                    style_attrs.append(f'fill="{fill_val}"')
                if styles[cls]['opacity']:
                    style_attrs.append(f'fill-opacity="{styles[cls]["opacity"]}"')
        
        if style_attrs:
            return f'{tag_start} {" ".join(style_attrs)}'
        return match.group(0) # No change if no matching class style

    # Regex to find elements with class. 
    # Example: <path class="st4" ...>
    # Group 1: <path 
    # Group 2: class value
    # We want to remove class="..." and add fill="..."
    
    # This regex is a bit simplistic, assumes class is before other attributes or we just replace the class attr.
    # Better approach: Match the whole tag opening, extract class, remove it, add style.
    
    # Let's try replacing `class="..."` with `fill="..."`
    
    def inline_style_replacer(match):
        full_tag = match.group(0)
        class_content = match.group(1)
        
        style_string = ""
        classes = class_content.split()
        for cls in classes:
             if cls in styles:
                if styles[cls]['fill']:
                    fill_val = styles[cls]['fill']
                    for old_id, new_id in id_map.items():
                        if f'#{old_id}' in fill_val:
                            fill_val = fill_val.replace(f'#{old_id}', f'#{new_id}')
                    style_string += f' fill="{fill_val}"'
                if styles[cls]['opacity']:
                    style_string += f' fill-opacity="{styles[cls]["opacity"]}"'
        
        # Remove class attribute and append styles
        return style_string

    new_content = re.sub(r'\s+class="([^"]+)"', inline_style_replacer, new_content)
    
    # Remove the style block
    new_content = re.sub(r'<style>.*?</style>', '', new_content, flags=re.DOTALL)
    
    # Clean up any potential double spaces
    # new_content = re.sub(r'\s+', ' ', new_content) 

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"Processed: {file_path}")

# Run for all SVGs in the directory
target_dir = 'assets/images/strength/category'
svg_files = glob.glob(os.path.join(target_dir, '*.svg'))

for svg_file in svg_files:
    if 'forearms.svg' in svg_file: # Skip the one that works, or process it too if needed (it doesn't use classes so likely safe)
        continue
    print(f"Fixing {svg_file}...")
    try:
        fix_svg(svg_file)
    except Exception as e:
        print(f"Failed to fix {svg_file}: {e}")
