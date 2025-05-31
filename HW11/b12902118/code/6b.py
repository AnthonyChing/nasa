from binascii import unhexlify

encrypted_flag_hex = "1180db634a13bb21d0923f9bd44b42058e28c59a7da7d46b4e5bbc2cc3943c9d9555480e88288dcf6bc9f36a4a06c003f6a41cb6fd511a50817d80870282867f740c8f7880a83fdaea321c3e967e83c26ab68133740dca2381a869dcea764755cb2380c425dec8"
known_prefix = b'NASA_HW11{'
key_len = 10
cipher = unhexlify(encrypted_flag_hex)
cipher_len = len(cipher)

for shift in range(cipher_len):
	key = bytearray(key_len)
	for i in range(key_len):
		key[(shift + i) % key_len] = cipher[(i + shift) % cipher_len] ^ known_prefix[i]

	flag = bytearray()
	for i in range(cipher_len):
		flag.append(cipher[i] ^ key[i % key_len])
	try:
		print(f"Shift: {shift} Flag: {flag.decode()}")
	except UnicodeDecodeError:
		print(f"Shift: {shift} Flag: {flag.hex()}")