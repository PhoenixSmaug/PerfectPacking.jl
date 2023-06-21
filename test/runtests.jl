println("Testing...")
using Test, PerfectPacking

result, _ = rectanglePacking(6, 6, [(1 => 6), (1 => 3), (5 => 1), (2 => 2), (3 => 2), (4 => 2), (4 => 1)], false, backtracking)
@test result == true

