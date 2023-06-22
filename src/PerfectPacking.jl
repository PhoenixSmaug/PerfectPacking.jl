module PerfectPacking
export Alg, rectanglePacking, backtracking, integerProgramming, dancingLinks

using ProgressMeter
using JuMP
using HiGHS
using DataStructures

@enum Alg begin
    backtracking = 1
    integerProgramming = 2
    dancingLinks = 3
end

"""
    rectanglePacking(h, w, rects, rot, alg)

Decides if perfect rectangle packing is possible and if so return it

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
- `rot`: If rectangles are allowed to be rotated by 90 degrees
- `alg`: Which exhaustive algorithm to use
"""
function rectanglePacking(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}}, rot::Bool, alg::Alg)
    # verify that area is valid
    totalArea = 0
    for i in rects
        totalArea += i[1] * i[2]
    end

    if totalArea != h * w
        println("Total area of rectangles is unequal to area of bounding rectangle")
        return false
    end

    # verify that all rectangles fit
    for i in rects
        if !rot
            if i[1] > h || i[2] > w
                println("Not all rectangles fit in bounding rectangle")
                return false
            end
        else
            if max(i[1], i[2]) > max(h, w) || min(i[1], i[2]) > min(h, w)
                println("Not all rectangles fit in bounding rectangle")
                return false
            end
        end
    end
    
    result = false
    output = nothing

    if alg == backtracking
        result, output = runBacktracking(h, w, rects, rot)
    elseif alg == integerProgramming
        result, output = runIntegerProgramming(h, w, rects, rot)
    end
    
    return result, output
end

"""
    runBacktracking(h, w, rects, rot)

Perfect rectangle packing using backtracking with top-left heuristic. The rectangles are sorted
by width and in each step the frist free tile beginning on the top-left is covered. If rotation
is allowed, squares need to handeled seperatly

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
- `rot`: If rectangles are allowed to be rotated by 90 degrees
"""
function runBacktracking(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}}, rot::Bool)
    if rot
        # filter out squares, since they don't need to be rotated
        squares = filter(x -> x[1] == x[2], rects)
        filter!(x -> x[1] != x[2], rects)
        sort!(rects, rev=true, by = x -> x[2])  # sort rectangles with descending width in preparation for top-left heuristic
        
        switch = x->Pair(x[2], x[1])  # generate rotated version of rectangles
        rectsRot = reverse(switch.(rects))

        return solveBacktrackingRot(h, w, vcat(rects, squares, rectsRot), length(rects))
    else
        sort!(rects, rev=true, by = x -> x[2])  # sort rectangles with descending width in preparation for top-left heuristic

        return solveBacktracking(h, w, rects)
    end
end

"""
    solveBacktracking(h, w, rects)

Perfect rectangle packing without rotations using backtracking with top-left heuristic.

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
"""
function solveBacktracking(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}})
    prog = ProgressUnknown("Backtracking search:")
    s = length(rects)

    tiles = fill(0, h, w)  # current state of square
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    x = y = kStart = steps = 1

    while true
        ProgressMeter.update!(prog, steps)

        # Try to place a rectangle on (x, y)

        done = false
        k = kStart  # only rectangles after kStart are allowed
        
        while k <= s && !done
            if used[k] == 0 && (x + rects[k][1] - 1 <= h && y + rects[k][2] - 1 <= w)  # piece not used and fits
                done = true

                # check permiter of rectangle for collisions with other rectangles

                for l = 0 : rects[k][1] - 1
                    if tiles[x + l, y] != 0 || tiles[x + l, y + rects[k][2] - 1] != 0
                        done = false
                        break
                    end
                end

                if done
                    for l = 0 : rects[k][2] - 1
                        if tiles[x, y + l] != 0 || tiles[x + rects[k][1] - 1, y + l] != 0
                            done = false
                            break
                        end
                    end
                end

                if !done
                    k += 1
                end
            else
                k += 1  # try next piece
            end
        end

        if done  # rectangle k can be placed on (x, y)
            push!(coords, Pair(x, y))
            tiles[x : x + rects[k][1] - 1, y : y + rects[k][2] - 1] = fill(k, rects[k][1], rects[k][2])  # fill tiles with selected square

            count += 1
            used[k] = count
            kStart = 1
        else  # no rectangle can be placed anymore, backtrack
            k = argmax(used)  # find which piece was last piece

            if !isempty(coords)
                last = pop!(coords)  # find coordinates of last piece
                tiles[last[1] : last[1] + rects[k][1] - 1, last[2] : last[2] + rects[k][2] - 1] = fill(0, rects[k][1], rects[k][2])  # remove from tiles
            end

            count -= 1
            used[k] = 0
            kStart = k + 1  # k does not work as next piece, do not include in next attempt
        end

        x, y = findNext(h, w, tiles)

        if count == s  # all s rectangles are placed
            return true, tiles
        elseif count == -1  # no rectangles are placed but kStart > s, so all combinations have been tried
            return false, nothing
        end

        steps += 1
    end
end

"""
    solveBacktrackingRot(h, w, rects)

Perfect rectangle packing with rotations using backtracking with top-left heuristic. In rects
each rectangle is given twice, one for each possible rotation. If a rectangle that is not a
square is choosen, used[s - k + 1] prevents us from choosing the other orientation of that
rectangle. 

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
- `numRects`: Number of rectangles that are not a square
"""
function solveBacktrackingRot(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}}, numRects::Int64)
    prog = ProgressUnknown("Backtracking search:")
    s = length(rects)

    tiles = fill(0, h, w)  # current state of square
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    x = y = kStart = steps = 1

    while true
        ProgressMeter.update!(prog, steps)

        # Try to place a rectangle on (x, y)

        done = false
        k = kStart  # only rectangles after kStart are allowed
        
        while (k <= s-numRects || (k <= s && count > 0)) && !done  # because of symmetry the first rectangle is always assumed to be non-rotated
            if used[k] == 0 && (x + rects[k][1] - 1 <= h && y + rects[k][2] - 1 <= w)  # piece not used and fits
                done = true

                # check permiter of rectangle for collisions with other rectangles

                for l = 0 : rects[k][1] - 1
                    if tiles[x + l, y] != 0 || tiles[x + l, y + rects[k][2] - 1] != 0
                        done = false
                        break
                    end
                end

                if done
                    for l = 0 : rects[k][2] - 1
                        if tiles[x, y + l] != 0 || tiles[x + rects[k][1] - 1, y + l] != 0
                            done = false
                            break
                        end
                    end
                end

                if !done
                    k += 1
                end
            else
                k += 1  # try next piece
            end
        end

        if done  # rectangle k can be placed on (x, y)
            push!(coords, Pair(x, y))
            tiles[x : x + rects[k][1] - 1, y : y + rects[k][2] - 1] = fill(k, rects[k][1], rects[k][2])  # fill tiles with selected square

            count += 1
            if k <= numRects || k > s-numRects  # check if true rectangle and not square
                used[s - k + 1] = -1  # different rotation can't be used anymore
            end

            used[k] = count
            kStart = 1
        else  # no rectangle can be placed anymore, backtrack
            k = argmax(used)  # find which piece was last piece

            if !isempty(coords)
                last = pop!(coords)  # find coordinates of last piece
                tiles[last[1] : last[1] + rects[k][1] - 1, last[2] : last[2] + rects[k][2] - 1] = fill(0, rects[k][1], rects[k][2])  # remove from tiles
            end

            count -= 1
            used[k] = 0

            if k <= numRects || k > s-numRects  # check if true rectangle and not square
                used[s - k + 1] = 0
            end

            kStart = k + 1  # k does not work as next piece, do not include in next attempt
        end

        x, y = findNext(h, w, tiles)

        if count == s-numRects  # all s rectangles are placed
            return true, tiles
        elseif count == -1  # no rectangles are placed but kStart > s-numRects, so all combinations have been tried
            return false, nothing
        end

        steps += 1
    end
end

"""
    findNext(h, w, tiles)

Find the first free slot in the matrix tiles, going first by row, then by column.

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `tiles`: Current occupation of rectangle to fill
"""
@inline function findNext(h::Int64, w::Int64, tiles::Matrix{Int64})
    for i in 1 : h
        for j in 1 : w
            if tiles[i, j] == 0
                return i, j
            end
        end
    end

    return h, w
end

"""
    runIntegerProgramming(h, w, rects, rot)

Perfect rectangle packing using Integer Programming and the open-source solver HiGHS. The model
is taken from M. Berger, M. Schröder, K.-H. Küfer, "A constraint programming approach for the
two-dimensional rectangular packing problem with orthogonal orientations", Berichte des
Fraunhofer ITWM, Nr. 147 (2008).

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
- `rot`: If rectangles are allowed to be rotated by 90 degrees
"""
function runIntegerProgramming(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}}, rot::Bool)
    if rot
        return solveIntegerProgrammingRot(h, w, rects)
    else
        return solveIntegerProgramming(h, w, rects)
    end
end

"""
    solveIntegerProgramming(h, w, rects, rot)

Perfect rectangle packing without rotations using Integer Programming and the open-source
solver HiGHS.

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
"""
function solveIntegerProgramming(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}})
    s = length(rects)
    model = Model(HiGHS.Optimizer)

    @variable(model, px[1:s], Int)  # x position
    @variable(model, py[1:s], Int)  # y position
    @variable(model, overlap[1:s, 1:s, 1:4], Bin)  # help variable to prevent overlap

    for i in 1 : s
        @constraint(model, px[i] >= 0)  # position is non-negative
        @constraint(model, py[i] >= 0)

        @constraint(model, px[i] + rects[i][2] <= w)  # rectangle is contained in square
        @constraint(model, py[i] + rects[i][1] <= h)
    end

    for i in 1 : s
        for j in i + 1 : s
            @constraint(model, px[i] - px[j] + rects[i][2] <= w * (1 - overlap[i, j, 1]))  # rectangle i is left of rectangle j
            @constraint(model, px[j] - px[i] + rects[j][2] <= w * (1 - overlap[i, j, 2]))  # rectangle i is right of rectangle j
            @constraint(model, py[i] - py[j] + rects[i][1] <= h * (1 - overlap[i, j, 3]))  # rectangle i is below rectangle j
            @constraint(model, py[j] - py[i] + rects[j][1] <= h * (1 - overlap[i, j, 4]))  # rectangle i is above rectangle j

            @constraint(model, sum(overlap[i, j, :]) >= 1)  # one of the cases must be true so that rectangles don't overlap
        end
    end

    optimize!(model)

    if (has_values(model))  # if solution was found
        output = fill(0, h, w)

        for i in 1 : s
            iPX = Int(round(value(px[i])))
            iPY = Int(round(value(py[i])))

            for x in iPX + 1 : iPX + rects[i][2] 
                for y in iPY + 1 : iPY + rects[i][1] 
                    output[y, x] = i
                end
            end
        end

        return true, output
    end

    return false, nothing
end

"""
    solveIntegerProgrammingRot(h, w, rects, rot)

Perfect rectangle packing with rotations using Integer Programming and the open-source
solver HiGHS.

# Arguments
- `h`: Height of rectangle to fill
- `w`: Width of rectangle to fill
- `rects`: Vector of rectangles to use for the packing; Encoded as Pair(height, width)
"""
function solveIntegerProgrammingRot(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}})
    s = length(rects)
    model = Model(HiGHS.Optimizer)

    @variable(model, sx[1:s], Int)  # width of rectangle i
    @variable(model, sy[1:s], Int)  # height of rectangle i
    @variable(model, px[1:s], Int)  # x position
    @variable(model, py[1:s], Int)  # y position
    @variable(model, o[1:s], Bin)  # orientation of rectangle
    @variable(model, overlap[1:s, 1:s, 1:4], Bin)  # help variable to prevent overlap

    for i in 1 : s
        @constraint(model, px[i] >= 0)  # position is non-negative
        @constraint(model, py[i] >= 0)

        @constraint(model, px[i] + sx[i] <= w)  # rectangle is contained in square
        @constraint(model, py[i] + sy[i] <= h)

        @constraint(model, (1 - o[i]) * rects[i][1] + o[i] * rects[i][2] == sx[i])  # determine size from orientation
        @constraint(model, o[i] * rects[i][1] + (1 - o[i]) * rects[i][2] == sy[i])
    end

    for i in 1 : s
        for j in i + 1 : s
            @constraint(model, px[i] - px[j] + sx[i] <= w * (1 - overlap[i, j, 1]))  # rectangle i is left of rectangle j
            @constraint(model, px[j] - px[i] + sx[j] <= w * (1 - overlap[i, j, 2]))  # rectangle i is right of rectangle j
            @constraint(model, py[i] - py[j] + sy[i] <= h * (1 - overlap[i, j, 3]))  # rectangle i is below rectangle j
            @constraint(model, py[j] - py[i] + sy[j] <= h * (1 - overlap[i, j, 4]))  # rectangle i is above rectangle j

            @constraint(model, sum(overlap[i, j, :]) >= 1)  # one of the cases must be true so that rectangles don't overlap
        end
    end

    optimize!(model)

    if (has_values(model))  # if solution was found
        output = fill(0, h, w)

        for i in 1 : s
            iPX = Int(round(value(px[i])))
            iPY = Int(round(value(py[i])))
            iSX = Int(round(value(sx[i])))
            iSY = Int(round(value(sy[i])))

            for x in iPX + 1 : iPX + iSX 
                for y in iPY + 1 : iPY + iSY
                    output[y, x] = i
                end
            end
        end

        return true, output
    end

    return false, nothing
end


end # module PerfectPacking
