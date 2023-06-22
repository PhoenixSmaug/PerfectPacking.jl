# PerfectPacking.jl

This library solves the NP-complete perfect rectangle packing problem, where smaller rectangles must be placed in a bounding rectangle without overlapping or leaving tiles uncovered. It can also solve the perfect rectangle packing problem with orthogonal rotation, where the smaller rectangles are allowed to be rotated. The common solving algorithms from literature are implemented.

### Backtracking

```julia
feasibility, solution = rectanglePacking(height, width, rectangles, rotAllowed, backtracking)
```

The most popular and generally the fastest algorithm is backtracking with the top-left heuristic. In each step, an attempt is made to place a new rectangle in the first free tile, proceeding first by rows and then by columns. To further reduce the search space, the rectangles are sorted by descending width.

### Integer Programming

```julia
feasibility, solution = rectanglePacking(height, width, rectangles, rotAllowed, integerProgramming)
```

The perfect rectangle packing problem is translated into an Integer Programming feasibility problem using a model from [this article](https://link.springer.com/chapter/10.1007/978-3-642-00142-0_69). Then it is solved with the open source ILP solver HiGHS. In many cases, it provides the quickest way to prove non-feasibility of the packing problem.

### Dancing Links

```julia
feasibility, solution = rectanglePacking(height, width, rectangles, rotAllowed, dancingLinks)
```

Knuth's famous dancing links algorithm can be used to solve the perfect rectangle packing problem, since it can be reduced to an exact cover problem. When the problem is feasible, it often outperforms the Integer Programming model, but can rarely compete with the classical backtracking approach.

(c) Christoph Muessig
