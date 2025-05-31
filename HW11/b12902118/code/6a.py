from Crypto.Util.number import inverse
from pwn import *

m =0xa34d80e56c2cd0d35209cb13e5665fc58176fac6b1fee26af23388deebee59da1a884cbba6111ea819f7a2059f0accd8b1e7e23dbe4d90896b2cd482c0b934d97e3bbdbfd26b968e9bfeb2f8df037cab44557d2cf6eb57385a191c3db536c62f781e598405bdd818ae98dfd7df48c4da55d9d5b49d75aa46c91a27a186b9bf77
r = remote('140.112.91.4', 1234)

def guess_number(num):
	r.recvuntil(b'Your choice: ')
	r.sendline(b'1')
	r.recvuntil(b'Guess a number: ')
	r.sendline(str(num).encode())
	line = r.recvline_contains(b'number I picked is')
	return int(line.decode().split('is')[1].split(',')[0].strip())

s0 = guess_number(1)
s1 = guess_number(2)
s2 = guess_number(3)

a = ((s2 - s1) * inverse(s1 - s0, m)) % m
c = (s1 - s0 * a) % m

print(f"a = {a}")
print(f"c = {c}")

def predict_number(num):
	r.recvuntil(b'Your choice: ')
	r.sendline(b'1')
	r.recvuntil(b'Guess a number: ')
	r.sendline(str(num).encode())

for i in range(101):
	next_number = (s2 * a + c) % m
	print(f"next_number = {next_number}")
	predict_number(next_number)
	s2 = next_number

r.recvuntil(b'Your choice: ')
r.sendline(b'2')
print(r.recvall(timeout=3).decode())
