from Crypto.Util.number import getPrime
import math

p = getPrime(2048)
q = getPrime(2048)
print(p, q)
n = p * q
lambdan = math.lcm(p-1, q-1)
e = 65537

def extended_gcd(a, b):
    old_r, r = a, b
    old_s, s = 1, 0
    old_t, t = 0, 1
    
    while r != 0:
        quotient = old_r // r
        old_r, r = r, old_r - quotient * r
        old_s, s = s, old_s - quotient * s
        old_t, t = t, old_t - quotient * t
    
    return old_r, old_s, old_t  # old_r is the gcd, old_s is the inverse of a mod b

# Calculate d: modular inverse of e modulo λ(n)
g, d, _ = extended_gcd(e, lambdan)

if g != 1:
    raise ValueError("e and λ(n) are not coprime, no modular inverse exists.")
else:
    # Ensure d is positive by adjusting it if necessary
    d = d % lambdan

print("n:", n)
print("e:", e)
print("d:", d)