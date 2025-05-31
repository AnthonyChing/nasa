from PIL import Image

image_file = "secret_mygo.png"
data = ""

# Open image
img = Image.open(image_file)

# Get pixels' values
pixels = list(img.getdata())

for i in range(len(pixels)//3):
    colors = list(pixels[i * 3]) + list(pixels[i * 3 + 1]) + list(pixels[i * 3 + 2])
    bits = []
    for j in range(8):
        bits.append(colors[j] % 2)
    # Convert bits to ASCII character
    char = chr(int("".join(map(str, bits)), 2))
    if char == "\x00":
        break
    data += char
# Print the extracted data
print(data)