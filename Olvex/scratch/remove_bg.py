from PIL import Image
import sys

def isolate_white_icon(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        # If it's bright white/off-white, keep it. Otherwise, make it transparent.
        # Check if R, G, B are all > 230
        if item[0] > 230 and item[1] > 230 and item[2] > 230:
            new_data.append(item)
        else:
            new_data.append((0, 0, 0, 0))
            
    img.putdata(new_data)
    img.save(output_path, "PNG")

if __name__ == "__main__":
    isolate_white_icon(sys.argv[1], sys.argv[2])
