from pwn import *
import hashlib

hash_map = {}
for i in range(2**24):
    prefix = hashlib.md5(str(i).encode()).hexdigest()[:8]
    hash_map[prefix] = i


def solve_pow(prefix):
    for i in range(2**24):
        if hashlib.md5(str(i).encode()).hexdigest()[:8] == prefix:
            return str(i)
    return None

def main():
	r = remote('140.112.91.4', 1234)
	r.recvuntil(b'Your choice:')
	r.sendline(b'4')
	for _ in range(10):
		line = r.recvline_contains(b'md5(i)[0:8] == "')
		prefix = line.decode().split('== "')[1].split('"')[0]
		ans = hash_map.get(prefix)
		print(f'Solved: {ans}')
		r.sendline(ans.encode())
	print(r.recvall(timeout=2).decode())

# if __name__ == '__main__':
#     main()

while True:
	prefix = input("Enter the prefix (or 'exit' to quit): ")
	if prefix.lower() == 'exit':
		break
	ans = solve_pow(prefix)
	if ans is not None:
		print(f'Solved: {ans}')
	else:
		print('No solution found for the given prefix.')