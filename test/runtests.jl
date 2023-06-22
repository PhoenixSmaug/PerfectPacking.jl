println("Testing...")
using Test, PerfectPacking

result, _ = rectanglePacking(6, 6, [(1 => 6), (1 => 3), (5 => 1), (2 => 2), (3 => 2), (4 => 2), (4 => 1)], false, backtracking)
@test result == true

result, _ = rectanglePacking(6, 6, [(5 => 1), (1 => 3), (5 => 1), (2 => 2), (3 => 2), (3 => 3), (4 => 1)], true, backtracking)
@test result == true
