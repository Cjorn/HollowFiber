module Output
import HDF5

"Output handler for writing to an HDF5 file"
mutable struct HDF5Output{sT, N}
    fpath::AbstractString  # Path to output file
    save_cond::sT  # callable, determines when data is saved and where it is interpolated
    ydims::NTuple{N, Int64}  # Dimensions of one array to be saved
    yname::AbstractString  # Name for solution (e.g. "Eω")
    tname::AbstractString  # Name for propagation direction (e.g. "z")
    saved::Integer  # How many points have been saved so far
end

"Simple constructor"
function HDF5Output(fpath, tmin, tmax, saveN::Integer, ydims;
                    yname="Eω", tname="z")
    save_cond = GridCondition(tmin, tmax, saveN)
    HDF5Output(fpath, save_cond, ydims, yname, tname)
end

"Internal constructor - creates datasets in the file"
function HDF5Output(fpath, save_cond, ydims, yname, tname)
    dims = (ydims..., 1)
    maxdims = (ydims..., -1)
    if isfile(fpath)
        error("Output file already exists!")
    end
    HDF5.h5open(fpath, "cw") do file
        HDF5.d_create(file, yname*"_real", HDF5.datatype(Float64), (dims, maxdims),
                      "chunk", dims)
        HDF5.d_create(file, yname*"_imag", HDF5.datatype(Float64), (dims, maxdims),
                      "chunk", dims)
        HDF5.d_create(file, tname, HDF5.datatype(Float64), ((1,), (-1,)),
                      "chunk", (1,))
    end
    HDF5Output(fpath, save_cond, ydims, yname, tname, 0)
end

"""Calling the output handler writes data to the file
    Arguments:
        y: current function value
        t: current propagation point
        dt: current stepsize
        yfun: callable which returns interpolated function value at different t
    Note that from RK45.jl, this will be called with yn and tn as arguments.
"""
function (o::HDF5Output)(y, t, dt, yfun)
    save, ts = o.save_cond(y, t, dt, o.saved)
    while save
        HDF5.h5open(o.fpath, "r+") do file
            idcs = fill(:, length(o.ydims))
            s = collect(size(file[o.yname*"_real"]))
            if s[end] < o.saved+1
                s[end] += 1
                HDF5.set_dims!(file[o.yname*"_real"], Tuple(s))
                HDF5.set_dims!(file[o.yname*"_imag"], Tuple(s))
            end
            yi = yfun(ts)
            file[o.yname*"_real"][idcs..., o.saved+1] = real(yi)
            file[o.yname*"_imag"][idcs..., o.saved+1] = imag(yi)
            s = collect(size(file[o.tname]))
            if s[end] < o.saved+1
                s[end] += 1
                HDF5.set_dims!(file[o.tname], Tuple(s))
            end
            file[o.tname][o.saved+1] = ts
            o.saved += 1
        end
        save, ts = o.save_cond(y, t, dt, o.saved)
    end

end

"Condition callable that distributes save points evenly on a grid"
struct GridCondition
    grid::Vector{Float64}
    saveN::Integer
end

function GridCondition(tmin, tmax, saveN)
    GridCondition(range(tmin, stop=tmax, length=saveN), saveN)
end

function (cond::GridCondition)(y, t, dt, saved)
    save = (saved < cond.saveN) && cond.grid[saved+1] < t
    if save
        return save, cond.grid[saved+1]
    else
        return save, 0
    end
end

"Condition which saves every native point of the propagation"
function always(y, t, dt, saved)
    return true, t
end

"Condition which saves every nth native point"
function every_nth(n)
    i = 0
    cond = let i = i, n = n
        function condition(y, t, dt, saved)
            if i % n == 0
                return true, t
            else
                return false, t
            end
            i += 1
        end
    end
    return cond
end
            

end
