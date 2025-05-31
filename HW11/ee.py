from binascii import hexlify
import secrets
def OTPEncrypt(msg: bytes) -> bytes:
    key_len = 10
    key = secrets.token_bytes(key_len)
    enc = bytes(msg[i] ^ key[i % key_len] for i in range(len(msg)))
    return enc

FLAG2 = "NASA_HW11{this_is_a_fake_flag_for_testing_purposes_only}"
print("My score on the exam?")
print("Oh, uh... yeah. I got 35. That's what I got. Definitely 35.")
print("What? You want to check my answer sheet because you think I'm lying?")
print("Fine. Here you go. This is my answer sheet... ENCRYPTED by a one-time pad!!!")

encrypted_flag = hexlify(OTPEncrypt(FLAG2.encode())).decode()
print(encrypted_flag)

print("You'll never get to check my actual score, fools!")