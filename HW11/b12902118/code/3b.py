from pwn import *
from Crypto.Util.number import bytes_to_long, long_to_bytes, inverse
from sympy.ntheory.modular import crt
from sympy import integer_nthroot

def get_pubkey():
    r = remote('140.112.91.4', 11452)
    r.recvuntil(b'==============================================================')
    r.recvuntil(b'==============================================================')
    r.sendline(b'1')
    data = r.recvline_contains(b'public key')
    r.close()
    s = data.decode()
    e, n = eval(s.split(':',1)[1].strip())
    return int(e), int(n)

def get_signature(msg_bytes):
    r = remote('140.112.91.4', 11452)
    r.recvuntil(b'==============================================================')
    r.recvuntil(b'==============================================================')
    r.sendline(b'2')
    r.recvuntil(b'sign:')
    r.send(msg_bytes + b'\n')
    data = r.recvline_contains(b'signature')
    r.close()
    sig = int(data.decode().split(':')[1].strip())
    return sig

def get_pubkey_and_cipher():
    e, n = get_pubkey()
    print(f"Public key: (e={e}, n={n})")
    m = bytes_to_long(b'name=soyo')
    m1_bytes = b'hello world'
    m1 = bytes_to_long(m1_bytes)
    m2 = (m * inverse(m1, n)) % n
    m2_bytes = long_to_bytes(m2)
    sig1 = get_signature(m1_bytes)
    sig2 = get_signature(m2_bytes)
    forged_sig = (sig1 * sig2) % n
    print(f"Forged signature: {forged_sig}")
    r = remote('140.112.91.4', 11451)
    r.recvuntil(b'ID: ')
    r.sendline(b'name=soyo')
    r.recvuntil(b'Signature: ')
    r.sendline(str(forged_sig).encode())
    r.recvuntil(b"========================================================================")
    r.recvuntil(b"========================================================================")
    r.sendline(b'1')
    data = r.recvline_contains(b'public key')
    s = data.decode()
    e, n = eval(s.split(':',1)[1].strip())
    print(f"Public key: (e={e}, n={n})")
    r.recvuntil(b"========================================================================")
    r.recvuntil(b"========================================================================")
    r.sendline(b'2')
    data = r.recvline_contains(b'encrypted diary')
    s = data.decode()
    c = int(s.split(':',1)[1].strip())
    print(f"Encrypted diary: {c}")
    return n, c

def main():
    e = 7
    n_list = []
    c_list = []
    for _ in range(e):
        n, c = get_pubkey_and_cipher()
        n_list.append(n)
        c_list.append(c)

    # Use CRT to combine the ciphertexts
    C, N = crt(n_list, c_list)
    C = int(C)
    # Compute the integer 7th root
    m, exact = integer_nthroot(C, e)
    if not exact:
        print("Root not exact, try more samples or check code.")
    else:
        print(long_to_bytes(m))

if __name__ == '__main__':
    main()