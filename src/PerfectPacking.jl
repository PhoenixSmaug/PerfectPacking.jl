module PerfectPacking
export Alg, rectanglePacking, backtracking, dancingLinks, integerProgramming

using ProgressMeter
using JuMP
using HiGHS
using DataStructures
using Suppressor#

@enum Alg begin
    backtracking = 1
    dancingLinks = 2
    integerProgramming = 3
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
    end
    
    return result, output
end

function runBacktracking(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}}, rot::Bool)
    if rot
        # TODO: Add vector completion, keep track of squares, order: [rects non-rot, squares, rects rot]
        return solveBacktrackingRot(h, w, rects)
    else
        return solveBacktracking(h, w, rects)
    end
end

function solveBacktracking(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}})
    prog = ProgressUnknown("Backtracking search:")
    s = length(rects)

    tiles = fill(0, h, w)  # current state of square
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    i = j = kStart = steps = 1

    while true
        ProgressMeter.update!(prog, steps)

        # Try to place a rectangle on (i, j)

        done = false
        k = kStart  # only rectangles after kStart are allowed
        
        while k <= s && !done
            if used[k] == 0 && (i + rects[k][1] - 1 <= h && j + rects[k][2] - 1 <= w)  # piece not used and fits
                done = true

                # check permiter of rectangle for collisions with other rectangles

                for l = 0 : rects[k][1] - 1
                    if tiles[i + l, j] != 0 || tiles[i + l, j + rects[k][2] - 1] != 0
                        done = false
                        break
                    end
                end

                if done
                    for l = 0 : rects[k][2] - 1
                        if tiles[i, j + l] != 0 || tiles[i + rects[k][1] - 1, j + l] != 0
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

        if done  # rectangle k can be placed on (i, j)
            push!(coords, Pair(i, j))
            tiles[i : i + rects[k][1] - 1, j : j + rects[k][2] - 1] = fill(k, rects[k][1], rects[k][2])  # fill tiles with selected square

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

        i, j = findNext(h, w, tiles)

        if count == s  # all s rectangles are placed
            return true, tiles
        elseif count == -1  # no rectangles are placed but kStart > s, so all combinations have been tried
            return false, nothing
        end

        steps += 1
    end
end

# TODO
# - Redefine k <= ceil(s/2) and used[s - k + 1] for more than one square

function solveBacktrackingRot(h::Int64, w::Int64, rects::Vector{Pair{Int64, Int64}})
    prog = ProgressUnknown("Backtracking search:")
    s = length(rects)

    tiles = fill(0, h, w)  # current state of square
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    i = j = kStart = steps = 1

    while true
        ProgressMeter.update!(prog, steps)

        # Try to place a rectangle on (i, j)

        done = false
        k = kStart  # only rectangles after kStart are allowed
        
        while (k <= ceil(s/2) || (k <= s && count > 0)) && !done  # because of symmetry the first rectangle is always assumed to be non-rotated (<= ceil(s/2))
            if used[k] == 0 && (i + rects[k][1] - 1 <= h && j + rects[k][2] - 1 <= w)  # piece not used and fits
                done = true

                # check permiter of rectangle for collisions with other rectangles

                for l = 0 : rects[k][1] - 1
                    if tiles[i + l, j] != 0 || tiles[i + l, j + rects[k][2] - 1] != 0
                        done = false
                        break
                    end
                end

                if done
                    for l = 0 : rects[k][2] - 1
                        if tiles[i, j + l] != 0 || tiles[i + rects[k][1] - 1, j + l] != 0
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

        if done  # rectangle k can be placed on (i, j)
            push!(coords, Pair(i, j))
            tiles[i : i + rects[k][1] - 1, j : j + rects[k][2] - 1] = fill(k, rects[k][1], rects[k][2])  # fill tiles with selected square

            count += 1
            used[s - k + 1] = -1  # different rotation can't be used anymore
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
            used[s - k + 1] = 0
            kStart = k + 1  # k does not work as next piece, do not include in next attempt
        end

        i, j = findNext(h, w, tiles)

        if count == s  # all s rectangles are placed
            return true, tiles
        elseif count == -1  # no rectangles are placed but kStart > ceil(s/2), so all combinations have been tried
            return false, nothing
        end

        steps += 1
    end
end

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


end # module PerfectPacking
