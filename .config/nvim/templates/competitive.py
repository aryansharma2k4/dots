# $(PROBLEM)

import sys
from collections import defaultdict, deque, Counter
from heapq import heappush, heappop
from itertools import accumulate, permutations, combinations
from math import gcd, inf, isqrt

# Buffered reads: input() is a syscall per line and is the usual reason a
# correct Python solution TLEs on a problem with 10^5 lines of input.
input = sys.stdin.readline

def ints():
    return list(map(int, input().split()))

def solve():
    pass

def main():
    t = 1
    # t = int(input())      # uncomment for multi-testcase problems
    for _ in range(t):
        solve()

if __name__ == "__main__":
    main()
