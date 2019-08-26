import Test: @test, @testset, @test_throws
import Luna: Output

@testset "HDF5" begin
    import HDF5
    shape = (1024, 4, 2)
    n = 11
    stat = randn()
    statsfun(y, t, dt) = Dict("stat" => stat)
    t0 = 0
    t1 = 10
    t = collect(range(t0, stop=t1, length=n))
    ω = randn((1024,))
    wd = dirname(@__FILE__)
    gitc = read(`git -C $wd rev-parse --short HEAD`, String)
    o = Output.HDF5Output("test.h5", t0, t1, n, shape, yname="y", tname="t", statsfun)
    extra = Dict()
    extra["ω"] = ω
    extra["git_commit"] = gitc
    o(extra)
    y0 = randn(ComplexF64, shape)
    y(t) = y0
    for (ii, ti) in enumerate(t)
        o(y0, ti, 0, y)
    end
    @test_throws ErrorException o(extra)
    @test o(extra, force=true) === nothing
    @test_throws ErrorException o("git_commit", gitc)
    HDF5.h5open("test.h5", "r") do file
        @test all(read(file["t"]) == t)
        yr = reinterpret(ComplexF64, read(file["y"]))
        @test all([all(yr[:, :, :, ii] == y0) for ii=1:n])
        @test all(ω == read(file["ω"]))
        @test gitc == read(file["git_commit"])
        @test all(read(file["stats"]["stat"]) .== stat)
    end
    rm("test.h5")
end

@testset "Memory" begin
    shape = (1024, 4, 2)
    n = 11
    stat = randn()
    statsfun(y, t, dt) = Dict("stat" => stat)
    t0 = 0
    t1 = 10
    t = collect(range(t0, stop=t1, length=n))
    ω = randn((1024,))
    wd = dirname(@__FILE__)
    gitc = read(`git -C $wd rev-parse --short HEAD`, String)
    o = Output.MemoryOutput(t0, t1, n, shape, statsfun, yname="y", tname="t")
    extra = Dict()
    extra["ω"] = ω
    extra["git_commit"] = gitc
    o(extra)
    y0 = randn(ComplexF64, shape)
    y(t) = y0
    for (ii, ti) in enumerate(t)
        o(y0, ti, 0, y)
    end
    @test all(o.data["t"] == t)
    @test all([all(o.data["y"][:, :, :, ii] == y0) for ii=1:n])
    @test all(ω == o.data["ω"])
    @test gitc == o.data["git_commit"]
    @test_throws ErrorException o(extra)
    @test o(extra, force=true) === nothing
    @test all(o.data["stats"]["stat"] .== stat)
end

@testset "HDF5 vs Memory" begin
    import Luna
    import Luna: Grid, Capillary, PhysData, Nonlinear, NonlinearRHS, Output, Stats, Maths, LinearOps
    import FFTW
    import HDF5

    a = 13e-6
    gas = :Ar
    pres = 5
    τ = 30e-15
    λ0 = 800e-9
    grid = Grid.RealGrid(15e-2, 800e-9, (160e-9, 3000e-9), 1e-12)
    m = Capillary.MarcatilliMode(a, gas, pres)
    energyfun = NonlinearRHS.energy_mode_avg(m)
    dens0 = PhysData.density(gas, pres)
    densityfun(z) = dens0
    responses = (Nonlinear.Kerr_field(PhysData.γ3_gas(gas)),)
    linop, βfun, frame_vel, αfun = LinearOps.make_const_linop(grid, m, λ0)
    normfun = NonlinearRHS.norm_mode_average(grid.ω, βfun)
    function gausspulse(t)
        It = Maths.gauss(t, fwhm=τ)
        ω0 = 2π*PhysData.c/λ0
        Et = @. sqrt(It)*cos(ω0*t)
    end
    in1 = (func=gausspulse, energy=1e-6)
    inputs = (in1, )
    Eω, transform, FT = Luna.setup(grid, energyfun, densityfun, normfun, responses, inputs)
    statsfun = Stats.collect_stats((Stats.ω0(grid), ))
    hdf5 = Output.HDF5Output("test.h5", 0, grid.zmax, 201, (length(grid.ω),), statsfun)
    mem = Output.MemoryOutput(0, grid.zmax, 201, (length(grid.ω),), statsfun)
    function output(args...)
        hdf5(args...)
        mem(args...)
    end
    for o in (hdf5, mem)
        o(Dict("ω" => grid.ω, "λ0" => λ0))
        o("τ", τ)
    end
    Luna.run(Eω, grid, linop, transform, FT, output)
    HDF5.h5open(hdf5.fpath, "r") do file
        @test read(file["ω"]) == mem.data["ω"]
        Eω = reinterpret(ComplexF64, read(file["Eω"]))
        @test Eω == mem.data["Eω"]
        @test read(file["stats"]["ω0"]) == mem.data["stats"]["ω0"]
        @test read(file["z"]) == mem.data["z"]
    end
    rm(hdf5.fpath)
end